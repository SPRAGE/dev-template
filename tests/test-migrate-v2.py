#!/usr/bin/env python3
"""Offline tests for the fingerprint-gated v1-to-v2 migrator."""

from __future__ import annotations

import importlib.util
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import yaml


sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[1]
MIGRATOR_PATH = REPO / "tools/migrate_v2.py"
TEMPLATE = REPO / "template"


def load_migrator():
    spec = importlib.util.spec_from_file_location("migrate_v2", MIGRATOR_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {MIGRATOR_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


migrator = load_migrator()


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def write_yaml(path: Path, data: dict) -> None:
    write_text(path, yaml.safe_dump(data, sort_keys=False))


def legacy_skill(path: Path, name: str) -> None:
    write_text(
        path / "SKILL.md",
        f"---\nname: {name}\ndescription: Legacy fixture skill.\n---\n\n# {name}\n",
    )
    write_yaml(path / "manifest.yaml", {"version": 1, "name": name})


def local_skill(path: Path, name: str) -> None:
    write_text(
        path / "SKILL.md",
        f"---\nname: {name}\ndescription: Project-owned test procedure.\n---\n\n# {name}\n",
    )
    write_yaml(path / "manifest.yaml", {"version": 1, "name": name, "managed_by": "local-test"})


def make_v1_project(root: Path) -> dict:
    (root / ".git").mkdir()
    shutil.copy2(TEMPLATE / "AI.md", root / "AI.md")
    ai = root / ".ai"
    project = {
        "version": 1,
        "project": {"name": "retained-project", "summary": "Retained domain summary."},
        "context": migrator.V1_CONTEXT,
        "spec": migrator.V1_SPEC,
        "budgets": migrator.V1_BUDGETS,
    }
    write_yaml(ai / "project.yaml", project)
    managed_files = {
        "policy.yaml": "legacy policy\n",
        "capabilities/map.yaml": "legacy capability map\n",
        "capabilities/profiles.yaml": "legacy profiles\n",
        "capabilities/runtimes/codex.yaml": "legacy codex runtime\n",
        "capabilities/runtimes/claude.yaml": "legacy claude runtime\n",
        "evals/contract-scenarios.yaml": "legacy scenarios\n",
        "generators/compile.py": "# legacy compiler\n",
    }
    for relative, content in managed_files.items():
        write_text(ai / relative, content)
    generated = f"<!-- {migrator.GENERATED_MARKER} -->\n"
    write_text(ai / "instructions.md", generated)
    write_text(ai / "methodology.md", generated)
    write_text(ai / "capabilities/map.md", generated)
    write_text(ai / "agents/legacy.yaml", "legacy agent\n")
    write_text(ai / "context/architecture-snapshot.md", "# Retained architecture\n")
    write_yaml(
        ai / "context/knowledge-sources.yaml",
        {
            "version": 1,
            "sources": [
                {
                    "id": "domain-docs",
                    "kind": "documentation",
                    "binding": "domain-docs-read",
                    "authority": "primary",
                    "scope": {"domains": ["billing"], "tenant_isolation": "source_enforced"},
                    "freshness": {"max_age": "P7D", "timestamp_field": "updated_at"},
                    "access": {"classification": "internal", "authorization": "source_enforced"},
                    "operations": {"search": "search", "fetch": "fetch", "mutate": None},
                    "citation": {
                        "id_field": "document_id",
                        "revision_field": "revision",
                        "locator_field": "url",
                    },
                }
            ],
        },
    )
    write_text(ai / "local/session.txt", "keep local state\n")
    legacy_skill(ai / "skills/planner", "planner")
    local_skill(ai / "skills/project-procedure", "project-procedure")

    manifest = {
        "version": 1,
        "migration": "v1-to-v2",
        "source_schema": 1,
        "target_schema": 2,
        "baseline_commit": "0000000000000000000000000000000000000000",
        "managed_files": {
            relative: migrator.sha256_file(ai / relative) for relative in managed_files
        },
        "managed_trees": {"agents": migrator.tree_digest(ai / "agents")},
        "retired_skills": {"planner": migrator.tree_digest(ai / "skills/planner")},
    }
    return manifest


class MigrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name) / "project"
        self.root.mkdir()
        self.manifest = make_v1_project(self.root)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def analysis(self):
        migrator.validate_manifest(self.manifest)
        return migrator.analyze(self.root, TEMPLATE, self.manifest)

    def test_clean_migration_preserves_identity_context_custom_skill_and_backup(self) -> None:
        analysis = self.analysis()
        self.assertEqual(analysis.status, "ready")
        self.assertEqual(analysis.retired_skills, ("planner",))
        self.assertEqual(analysis.preserved_skills, ("project-procedure",))

        backup = migrator.migrate(self.root, TEMPLATE, self.manifest, analysis)
        project = yaml.safe_load((self.root / ".ai/project.yaml").read_text(encoding="utf-8"))
        self.assertEqual(project["version"], 2)
        self.assertEqual(project["project"]["name"], "retained-project")
        self.assertEqual(project["project"]["summary"], "Retained domain summary.")
        self.assertTrue((self.root / ".ai/context/architecture-snapshot.md").is_file())
        self.assertTrue((self.root / ".ai/context/knowledge-sources.yaml").is_file())
        self.assertTrue((self.root / ".ai/local/session.txt").is_file())
        self.assertFalse((self.root / ".ai/skills/planner").exists())
        self.assertTrue((self.root / ".ai/skills/project-procedure/SKILL.md").is_file())
        self.assertTrue((self.root / ".ai/skills/agent-context/SKILL.md").is_file())
        self.assertTrue((backup / "ai-v1.tar.gz").is_file())
        self.assertTrue((backup / "result.yaml").is_file())
        self.assertTrue((self.root / ".codex/config.toml").is_file())
        self.assertTrue((self.root / ".claude/agents/reviewer.md").is_file())

        again = migrator.analyze(self.root, TEMPLATE, self.manifest)
        self.assertEqual(again.status, "already-v2")

    def test_customized_core_stops_before_changes(self) -> None:
        write_text(self.root / ".ai/policy.yaml", "custom policy\n")
        customized = migrator.tree_digest(self.root / ".ai")
        with self.assertRaisesRegex(migrator.MigrationConflict, "customized managed v1 source"):
            self.analysis()
        self.assertEqual(yaml.safe_load((self.root / ".ai/project.yaml").read_text())["version"], 1)
        self.assertEqual(migrator.tree_digest(self.root / ".ai"), customized)

    def test_customized_retired_skill_is_preserved(self) -> None:
        with (self.root / ".ai/skills/planner/SKILL.md").open("a", encoding="utf-8") as handle:
            handle.write("\nProject-specific planning rule.\n")
        analysis = self.analysis()
        self.assertEqual(analysis.retired_skills, ())
        self.assertIn("planner", analysis.preserved_skills)
        migrator.migrate(self.root, TEMPLATE, self.manifest, analysis)
        self.assertIn(
            "Project-specific planning rule.",
            (self.root / ".ai/skills/planner/SKILL.md").read_text(encoding="utf-8"),
        )

    def test_unknown_empty_managed_directory_stops_before_changes(self) -> None:
        (self.root / ".ai/evals/project-owned").mkdir()
        before = migrator.tree_digest(self.root / ".ai")
        with self.assertRaisesRegex(migrator.MigrationConflict, "unknown directories"):
            self.analysis()
        self.assertEqual(migrator.tree_digest(self.root / ".ai"), before)

    def test_post_swap_failure_rolls_back_v1_tree(self) -> None:
        analysis = self.analysis()
        before = migrator.tree_digest(self.root / ".ai")
        write_text(self.root / "AGENTS.md", "custom provider guidance\n")
        original_compile = migrator.compile_project

        def fail_final_compile(project_root: Path, *, check: bool = False) -> None:
            if project_root.resolve() == self.root.resolve():
                write_text(self.root / "AGENTS.md", "partial generated output\n")
                raise subprocess.CalledProcessError(1, ["compiler"])
            original_compile(project_root, check=check)

        with mock.patch.object(migrator, "compile_project", side_effect=fail_final_compile):
            with self.assertRaises(subprocess.CalledProcessError):
                migrator.migrate(self.root, TEMPLATE, self.manifest, analysis)

        self.assertEqual(migrator.tree_digest(self.root / ".ai"), before)
        self.assertEqual(yaml.safe_load((self.root / ".ai/project.yaml").read_text())["version"], 1)
        self.assertEqual((self.root / "AGENTS.md").read_text(encoding="utf-8"), "custom provider guidance\n")

    def test_staged_install_failure_restores_moved_v1_tree(self) -> None:
        analysis = self.analysis()
        before = migrator.tree_digest(self.root / ".ai")
        original_rename = Path.rename

        def fail_staged_install(source: Path, target: Path) -> Path:
            if source.name == ".ai" and source.parent.name == "staged-project":
                raise OSError("synthetic staged install failure")
            return original_rename(source, target)

        with mock.patch.object(Path, "rename", autospec=True, side_effect=fail_staged_install):
            with self.assertRaisesRegex(OSError, "synthetic staged install failure"):
                migrator.migrate(self.root, TEMPLATE, self.manifest, analysis)

        self.assertTrue((self.root / ".ai").is_dir())
        self.assertEqual(migrator.tree_digest(self.root / ".ai"), before)
        self.assertEqual(yaml.safe_load((self.root / ".ai/project.yaml").read_text())["version"], 1)

    def test_failed_v2_reconciliation_restores_generated_surfaces(self) -> None:
        analysis = self.analysis()
        migrator.migrate(self.root, TEMPLATE, self.manifest, analysis)
        instruction_path = self.root / ".ai/instructions.md"
        adapter_path = self.root / "AGENTS.md"
        instruction_before = instruction_path.read_text(encoding="utf-8")
        adapter_before = adapter_path.read_text(encoding="utf-8")

        def fail_compile(project_root: Path, *, check: bool = False) -> None:
            write_text(project_root / ".ai/instructions.md", "partial internal output\n")
            write_text(project_root / "AGENTS.md", "partial adapter output\n")
            raise subprocess.CalledProcessError(1, ["compiler"])

        with mock.patch.object(migrator, "compile_project", side_effect=fail_compile):
            with self.assertRaises(subprocess.CalledProcessError):
                migrator.reconcile_generated_surfaces(self.root)

        self.assertEqual(instruction_path.read_text(encoding="utf-8"), instruction_before)
        self.assertEqual(adapter_path.read_text(encoding="utf-8"), adapter_before)

    def test_provider_link_failure_rolls_back_tree_and_created_provider_directory(self) -> None:
        analysis = self.analysis()
        before = migrator.tree_digest(self.root / ".ai")

        def fail_provider_links(project_root: Path) -> None:
            link = project_root / ".agents/skills"
            link.parent.mkdir(parents=True)
            link.symlink_to("../.ai/skills", target_is_directory=True)
            raise OSError("synthetic provider link failure")

        with mock.patch.object(migrator, "ensure_provider_skill_links", side_effect=fail_provider_links):
            with self.assertRaisesRegex(OSError, "synthetic provider link failure"):
                migrator.migrate(self.root, TEMPLATE, self.manifest, analysis)

        self.assertEqual(migrator.tree_digest(self.root / ".ai"), before)
        self.assertFalse((self.root / ".agents").exists())
        self.assertEqual(yaml.safe_load((self.root / ".ai/project.yaml").read_text())["version"], 1)


if __name__ == "__main__":
    unittest.main()
