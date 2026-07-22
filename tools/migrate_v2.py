#!/usr/bin/env python3
"""Safely migrate a dev-template schema-v1 project to schema v2."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import yaml


GENERATED_MARKER = "Generated from .ai/ by .ai/generators/compile.py. Do not edit directly."
PROJECT_MARKERS = (".git", "flake.nix", "package.json", "Cargo.toml", "pyproject.toml", "go.mod")
V1_CONTEXT = {
    "always": ["AI.md", ".ai/instructions.md"],
    "conditional": {
        "architecture": ".ai/context/architecture-snapshot.md",
        "conventions": ".ai/context/conventions.md",
        "decisions": ".ai/context/decisions.md",
        "active": ".ai/context/active-context.md",
    },
}
V1_SPEC = {
    "policy": ".ai/policy.yaml",
    "contract_evals": ".ai/evals/contract-scenarios.yaml",
}
V1_BUDGETS = {
    "always_loaded_tokens": 2400,
    "adapter_tokens": 500,
    "skill_descriptions_tokens": 900,
    "skill_entry_tokens": 1200,
    "agent_contract_tokens": 800,
}
GENERATED_V1_FILES = ("instructions.md", "methodology.md", "capabilities/map.md")
V1_MANAGED_FILES = frozenset(
    {
        "policy.yaml",
        "capabilities/map.yaml",
        "capabilities/profiles.yaml",
        "capabilities/runtimes/codex.yaml",
        "capabilities/runtimes/claude.yaml",
        "evals/contract-scenarios.yaml",
        "generators/compile.py",
    }
)
MANAGED_TOP_LEVEL = {
    "project.yaml",
    "policy.yaml",
    "instructions.md",
    "methodology.md",
    "capabilities",
    "agents",
    "evals",
    "generators",
    "skills",
    "catalog",
    "tools",
}
STATE_DIRECTORIES = {"local", "tmp", "sessions", "logs"}
PROVIDER_DIRECTORIES = (".agents", ".claude", ".codex")
GENERATED_SURFACES = (
    ".ai/instructions.md",
    ".ai/methodology.md",
    ".ai/capabilities/map.md",
    "AGENTS.md",
    "CLAUDE.md",
    "CODEX.md",
    ".codex/config.toml",
    ".codex/agents",
    ".claude/agents",
    ".agents/skills",
    ".claude/skills",
    ".codex/skills",
)


class MigrationConflict(RuntimeError):
    """Raised when an automatic migration would overwrite semantic customization."""


@dataclass(frozen=True)
class Analysis:
    status: str
    identity: dict[str, str]
    retired_skills: tuple[str, ...]
    preserved_skills: tuple[str, ...]
    notes: tuple[str, ...]


@dataclass(frozen=True)
class GeneratedSurfaceSnapshot:
    present: tuple[str, ...]
    provider_directories: tuple[str, ...]


def load_yaml(path: Path) -> dict:
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, yaml.YAMLError) as error:
        raise MigrationConflict(f"cannot read {path}: {error}") from error
    if not isinstance(data, dict):
        raise MigrationConflict(f"{path} must contain a YAML mapping")
    return data


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tree_digest(directory: Path) -> str:
    """Hash paths, types, link targets, and file content in a stable order."""
    digest = hashlib.sha256()
    entries = sorted(directory.rglob("*"), key=lambda item: item.relative_to(directory).as_posix())
    for entry in entries:
        relative = entry.relative_to(directory).as_posix().encode("utf-8")
        digest.update(relative + b"\0")
        if entry.is_symlink():
            digest.update(b"L\0" + os.readlink(entry).encode("utf-8") + b"\n")
        elif entry.is_dir():
            digest.update(b"D\n")
        elif entry.is_file():
            digest.update(b"F\0" + sha256_file(entry).encode("ascii") + b"\n")
        else:
            digest.update(b"O\n")
    return digest.hexdigest()


def copy_entry(source: Path, target: Path) -> None:
    if target.exists() or target.is_symlink():
        if target.is_dir() and not target.is_symlink():
            shutil.rmtree(target)
        else:
            target.unlink()
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        target.symlink_to(os.readlink(source), target_is_directory=source.is_dir())
    elif source.is_dir():
        shutil.copytree(source, target, symlinks=True)
    else:
        shutil.copy2(source, target, follow_symlinks=False)


def validate_manifest(manifest: dict) -> None:
    expected = {
        "version",
        "migration",
        "source_schema",
        "target_schema",
        "baseline_commit",
        "managed_files",
        "managed_trees",
        "retired_skills",
    }
    if set(manifest) != expected:
        raise MigrationConflict("migration manifest has missing or unused fields")
    if not (
        type(manifest["version"]) is int
        and manifest["version"] == 1
        and manifest["migration"] == "v1-to-v2"
        and type(manifest["source_schema"]) is int
        and manifest["source_schema"] == 1
        and type(manifest["target_schema"]) is int
        and manifest["target_schema"] == 2
    ):
        raise MigrationConflict("migration manifest has an unsupported version transition")
    if not isinstance(manifest["baseline_commit"], str) or not re.fullmatch(
        r"[0-9a-f]{40}", manifest["baseline_commit"]
    ):
        raise MigrationConflict("migration manifest baseline_commit must be a full commit SHA")
    managed_files = manifest["managed_files"]
    if not isinstance(managed_files, dict) or set(managed_files) != V1_MANAGED_FILES:
        raise MigrationConflict("migration manifest must fingerprint every managed v1 file exactly once")
    for relative, digest in managed_files.items():
        if (
            not isinstance(relative, str)
            or not relative
            or Path(relative).is_absolute()
            or ".." in Path(relative).parts
            or not isinstance(digest, str)
            or not re.fullmatch(r"[0-9a-f]{64}", digest)
        ):
            raise MigrationConflict("migration manifest has an invalid managed file fingerprint")
    managed_trees = manifest["managed_trees"]
    if not isinstance(managed_trees, dict) or set(managed_trees) != {"agents"}:
        raise MigrationConflict("migration manifest must fingerprint the complete v1 agent tree")
    if not isinstance(managed_trees["agents"], str) or not re.fullmatch(
        r"[0-9a-f]{64}", managed_trees["agents"]
    ):
        raise MigrationConflict("migration manifest has an invalid agent tree fingerprint")
    retired_skills = manifest["retired_skills"]
    if not isinstance(retired_skills, dict):
        raise MigrationConflict("migration manifest retired_skills must be a mapping")
    for name, digest in retired_skills.items():
        if (
            not isinstance(name, str)
            or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name)
            or not isinstance(digest, str)
            or not re.fullmatch(r"[0-9a-f]{64}", digest)
        ):
            raise MigrationConflict("migration manifest has an invalid retired skill fingerprint")


def validate_v1_project(project_path: Path) -> dict[str, str]:
    project = load_yaml(project_path)
    if project.get("version") == 2:
        return {}
    expected_keys = {"version", "project", "context", "spec", "budgets"}
    if set(project) != expected_keys or project.get("version") != 1:
        raise MigrationConflict(".ai/project.yaml is neither the supported v1 schema nor schema v2")
    identity = project.get("project")
    if not isinstance(identity, dict) or set(identity) != {"name", "summary"}:
        raise MigrationConflict("v1 project identity has unsupported customization")
    if not all(isinstance(identity[field], str) and identity[field] for field in ("name", "summary")):
        raise MigrationConflict("v1 project identity fields must be non-empty strings")
    if project.get("context") != V1_CONTEXT or project.get("spec") != V1_SPEC or project.get("budgets") != V1_BUDGETS:
        raise MigrationConflict(
            "v1 project routing, spec paths, or budgets were customized; merge those semantics manually"
        )
    return {"name": identity["name"], "summary": identity["summary"]}


def validate_generated_v1(ai: Path) -> None:
    for relative in GENERATED_V1_FILES:
        candidate = ai / relative
        if candidate.exists() and GENERATED_MARKER not in candidate.read_text(encoding="utf-8"):
            raise MigrationConflict(f"generated v1 file is customized and cannot be replaced automatically: .ai/{relative}")


def validate_current_v2_additions(ai: Path, template_ai: Path) -> None:
    """Permit exact v2 catalog/tool assets that conservative sync added to a v1 project."""
    for name in ("catalog", "tools"):
        candidate = ai / name
        if not candidate.exists():
            continue
        expected = template_ai / name
        if not candidate.is_dir() or tree_digest(candidate) != tree_digest(expected):
            raise MigrationConflict(f".ai/{name} differs from the target v2 asset; preserve and reconcile it manually")


def validate_managed_directory_contents(ai: Path) -> list[str]:
    allowed = {
        "capabilities": {
            "map.md",
            "map.yaml",
            "profiles.yaml",
            "runtimes/codex.yaml",
            "runtimes/claude.yaml",
        },
        "evals": {"contract-scenarios.yaml"},
        "generators": {"compile.py"},
    }
    allowed_directories = {"capabilities": {"runtimes"}, "evals": set(), "generators": set()}
    conflicts: list[str] = []
    for directory, expected_files in allowed.items():
        source = ai / directory
        actual_files = {
            path.relative_to(source).as_posix()
            for path in source.rglob("*")
            if path.is_file() or path.is_symlink()
        }
        extras = actual_files - expected_files
        if extras:
            conflicts.append(f"unknown files in .ai/{directory}: {', '.join(sorted(extras))}")
        actual_directories = {
            path.relative_to(source).as_posix()
            for path in source.rglob("*")
            if path.is_dir() and not path.is_symlink()
        }
        extra_directories = actual_directories - allowed_directories[directory]
        if extra_directories:
            conflicts.append(
                f"unknown directories in .ai/{directory}: {', '.join(sorted(extra_directories))}"
            )
    return conflicts


def analyze(root: Path, template: Path, manifest: dict) -> Analysis:
    if not any((root / marker).exists() for marker in PROJECT_MARKERS):
        raise MigrationConflict("no project root marker found; run the migration from the project root")
    ai = root / ".ai"
    if not ai.is_dir():
        raise MigrationConflict(".ai/ is missing; use onboard instead of migrate-v2")
    identity = validate_v1_project(ai / "project.yaml")
    if not identity:
        return Analysis("already-v2", {}, (), (), ("schema v2 is already active",))

    template_ai = template / ".ai"
    if load_yaml(template_ai / "project.yaml").get("version") != 2:
        raise MigrationConflict("target template is not schema v2")
    validate_generated_v1(ai)
    validate_current_v2_additions(ai, template_ai)

    conflicts: list[str] = []
    for relative, expected_hash in manifest["managed_files"].items():
        candidate = ai / relative
        if not candidate.is_file():
            conflicts.append(f"missing managed v1 source: .ai/{relative}")
        elif sha256_file(candidate) != expected_hash:
            conflicts.append(f"customized managed v1 source: .ai/{relative}")
    agents = ai / "agents"
    if not agents.is_dir():
        conflicts.append("missing managed v1 source tree: .ai/agents")
    elif tree_digest(agents) != manifest["managed_trees"]["agents"]:
        conflicts.append("customized managed v1 source tree: .ai/agents")

    conflicts.extend(validate_managed_directory_contents(ai))

    retired: list[str] = []
    preserved: list[str] = []
    skills = ai / "skills"
    if skills.exists() and not skills.is_dir():
        conflicts.append(".ai/skills is not a directory")
    if skills.is_dir():
        for skill in sorted(skills.iterdir(), key=lambda item: item.name):
            if not skill.is_dir():
                preserved.append(skill.name)
                continue
            expected_hash = manifest["retired_skills"].get(skill.name)
            if expected_hash and tree_digest(skill) == expected_hash:
                retired.append(skill.name)
                continue
            if skill.name == "agent-context":
                expected = template_ai / "skills/agent-context"
                if tree_digest(skill) != tree_digest(expected):
                    conflicts.append(".ai/skills/agent-context collides with the v2 managed default")
                continue
            preserved.append(skill.name)

    if (ai / "local").is_symlink():
        conflicts.append(".ai/local is a symlink; use a real directory before creating a recovery archive")

    if conflicts:
        rendered = "\n".join(f"- {conflict}" for conflict in conflicts)
        raise MigrationConflict(f"automatic migration stopped before making changes:\n{rendered}")
    notes = (
        "project identity and .ai/context are preserved",
        "custom and unknown skills remain active",
        "a complete v1 .ai archive is retained under .ai/local/migrations",
    )
    return Analysis("ready", identity, tuple(retired), tuple(preserved), notes)


def merge_preserved_state(old_ai: Path, staged_ai: Path, analysis: Analysis) -> None:
    context = old_ai / "context"
    if context.exists():
        copy_entry(context, staged_ai / "context")

    for name in STATE_DIRECTORIES:
        source = old_ai / name
        if source.exists() or source.is_symlink():
            copy_entry(source, staged_ai / name)

    old_skills = old_ai / "skills"
    for name in analysis.preserved_skills:
        source = old_skills / name
        target = staged_ai / "skills" / name
        if target.exists() or target.is_symlink():
            raise MigrationConflict(f"preserved skill collides with a v2 default: {name}")
        copy_entry(source, target)

    for entry in old_ai.iterdir():
        if entry.name in MANAGED_TOP_LEVEL or entry.name in STATE_DIRECTORIES or entry.name == "context":
            continue
        target = staged_ai / entry.name
        if target.exists() or target.is_symlink():
            raise MigrationConflict(f"custom .ai entry collides with v2 managed content: {entry.name}")
        copy_entry(entry, target)


def set_project_identity(staged_ai: Path, identity: dict[str, str]) -> None:
    project_path = staged_ai / "project.yaml"
    project = load_yaml(project_path)
    project["project"] = identity
    project_path.write_text(yaml.safe_dump(project, sort_keys=False), encoding="utf-8")


def compile_project(project_root: Path, *, check: bool = False) -> None:
    compiler = project_root / ".ai/generators/compile.py"
    command = [sys.executable, str(compiler), "--root", str(project_root)]
    if check:
        command.append("--check")
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL)


def snapshot_generated_surfaces(root: Path, destination: Path) -> GeneratedSurfaceSnapshot:
    present: list[str] = []
    for relative in GENERATED_SURFACES:
        source = root / relative
        if source.exists() or source.is_symlink():
            copy_entry(source, destination / relative)
            present.append(relative)
    provider_directories = tuple(
        relative
        for relative in PROVIDER_DIRECTORIES
        if (root / relative).exists() or (root / relative).is_symlink()
    )
    return GeneratedSurfaceSnapshot(tuple(present), provider_directories)


def restore_generated_surfaces(root: Path, snapshot: Path, state: GeneratedSurfaceSnapshot) -> None:
    for relative in GENERATED_SURFACES:
        target = root / relative
        if target.exists() or target.is_symlink():
            if target.is_dir() and not target.is_symlink():
                shutil.rmtree(target)
            else:
                target.unlink()
        if relative in state.present:
            copy_entry(snapshot / relative, target)
    for relative in PROVIDER_DIRECTORIES:
        provider = root / relative
        if (
            relative not in state.provider_directories
            and provider.is_dir()
            and not provider.is_symlink()
        ):
            try:
                provider.rmdir()
            except OSError:
                pass


def ensure_provider_skill_links(root: Path) -> None:
    for provider in (".agents", ".claude", ".codex"):
        link = root / provider / "skills"
        expected = "../.ai/skills"
        if link.is_symlink() and os.readlink(link) == expected:
            continue
        if not link.exists() and not link.is_symlink():
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(expected, target_is_directory=True)


def reconcile_generated_surfaces(root: Path) -> None:
    """Regenerate an existing v2 project without leaving partial outputs on failure."""
    with tempfile.TemporaryDirectory(prefix=".ai-reconcile-v2-", dir=root) as temporary:
        snapshot = Path(temporary) / "generated-rollback"
        state = snapshot_generated_surfaces(root, snapshot)
        try:
            compile_project(root)
            compile_project(root, check=True)
            ensure_provider_skill_links(root)
        except BaseException:
            restore_generated_surfaces(root, snapshot, state)
            raise


def build_staged_project(root: Path, template: Path, analysis: Analysis, work: Path) -> tuple[Path, Path]:
    staged_root = work / "staged-project"
    staged_root.mkdir()
    staged_ai = staged_root / ".ai"
    shutil.copytree(template / ".ai", staged_ai, symlinks=True)
    merge_preserved_state(root / ".ai", staged_ai, analysis)
    set_project_identity(staged_ai, analysis.identity)

    ai_md_source = root / "AI.md"
    if not ai_md_source.is_file():
        ai_md_source = template / "AI.md"
    shutil.copy2(ai_md_source, staged_root / "AI.md")
    compile_project(staged_root)
    compile_project(staged_root, check=True)
    return staged_root, staged_ai


def write_backup(old_ai: Path, staged_ai: Path, manifest: dict, analysis: Analysis) -> Path:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    backup = staged_ai / "local/migrations" / f"v1-to-v2-{timestamp}"
    suffix = 1
    while backup.exists():
        backup = backup.with_name(f"v1-to-v2-{timestamp}-{suffix}")
        suffix += 1
    backup.mkdir(parents=True)
    archive_path = backup / "ai-v1.tar.gz"
    with tarfile.open(archive_path, "w:gz") as archive:
        archive.add(old_ai, arcname=".ai", recursive=True)
    record = {
        "version": 1,
        "migration": manifest["migration"],
        "source_schema": manifest["source_schema"],
        "target_schema": manifest["target_schema"],
        "baseline_commit": manifest["baseline_commit"],
        "applied_at": datetime.now(timezone.utc).isoformat(),
        "retired_skills": list(analysis.retired_skills),
        "preserved_skills": list(analysis.preserved_skills),
        "backup": "ai-v1.tar.gz",
    }
    (backup / "result.yaml").write_text(yaml.safe_dump(record, sort_keys=False), encoding="utf-8")
    return backup


def migrate(root: Path, template: Path, manifest: dict, analysis: Analysis) -> Path:
    if analysis.status != "ready":
        raise MigrationConflict(f"cannot apply migration in state {analysis.status}")
    old_ai = root / ".ai"
    with tempfile.TemporaryDirectory(prefix=".ai-migrate-v2-", dir=root) as temporary:
        work = Path(temporary)
        staged_root, staged_ai = build_staged_project(root, template, analysis, work)
        backup = write_backup(old_ai, staged_ai, manifest, analysis)
        backup_relative = backup.relative_to(staged_ai)
        generated_snapshot = work / "generated-rollback"
        generated_state = snapshot_generated_surfaces(root, generated_snapshot)

        rollback_ai = work / "ai-v1-rollback"
        try:
            old_ai.rename(rollback_ai)
            staged_ai.rename(old_ai)
            compile_project(root)
            compile_project(root, check=True)
            ensure_provider_skill_links(root)
        except BaseException:
            rollback_present = rollback_ai.exists() or rollback_ai.is_symlink()
            if rollback_present and (old_ai.exists() or old_ai.is_symlink()):
                failed_ai = work / "ai-v2-failed"
                old_ai.rename(failed_ai)
            if rollback_present:
                rollback_ai.rename(old_ai)
            restore_generated_surfaces(root, generated_snapshot, generated_state)
            raise
    return root / ".ai" / backup_relative


def print_analysis(analysis: Analysis) -> None:
    print(f"migration status: {analysis.status}")
    if analysis.identity:
        print(f"project identity: {analysis.identity['name']}")
    print("retire unchanged v1 skills: " + (", ".join(analysis.retired_skills) or "none"))
    print("preserve custom/unknown skills: " + (", ".join(analysis.preserved_skills) or "none"))
    for note in analysis.notes:
        print(f"note: {note}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="project root (default: current directory)")
    parser.add_argument("--template", type=Path, required=True, help="schema-v2 template directory")
    parser.add_argument("--manifest", type=Path, required=True, help="v1 fingerprint manifest")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="preflight only (default)")
    mode.add_argument("--apply", action="store_true", help="apply after a successful preflight")
    args = parser.parse_args()

    try:
        root = args.root.resolve()
        template = args.template.resolve()
        manifest = load_yaml(args.manifest.resolve())
        validate_manifest(manifest)
        analysis = analyze(root, template, manifest)
        print_analysis(analysis)
        if analysis.status == "already-v2":
            if args.apply:
                reconcile_generated_surfaces(root)
                print("schema-v2 generated outputs reconciled")
            else:
                compile_project(root, check=True)
                print("schema-v2 generated outputs are current")
            return 0
        with tempfile.TemporaryDirectory(prefix=".ai-migrate-v2-check-", dir=root) as temporary:
            build_staged_project(root, template, analysis, Path(temporary))
        print("preflight: target schema compiles and generated outputs are current")
        if not args.apply:
            print("dry run only; rerun with --apply to migrate")
            return 0
        backup = migrate(root, template, manifest, analysis)
        print(f"migration applied; recovery archive: {backup.relative_to(root)}/ai-v1.tar.gz")
        return 0
    except (MigrationConflict, OSError, subprocess.CalledProcessError, tarfile.TarError) as error:
        print(f"migrate-v2: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
