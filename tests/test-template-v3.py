#!/usr/bin/env python3
"""Behavioral checks for project preservation, profiles, and recoverable v3 upgrades."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import tomllib
import unittest
from unittest.mock import patch

import yaml

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("template_tool", REPO / "tools/template.py")
t = importlib.util.module_from_spec(spec)
spec.loader.exec_module(t)


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / "project"
        self.root.mkdir()
        self.put("Cargo.toml", "[package]\nname = 'example'\n")
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.addCleanup(self.output.__exit__, None, None, None)

    def put(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def onboard(self):
        t.sync(REPO, self.root, onboard=True)

    def legacy(self):
        shutil.copytree(REPO / "compat/v2", self.root, dirs_exist_ok=True, symlinks=True)
        legacy_spec = importlib.util.spec_from_file_location("legacy", self.root / ".ai/generators/compile.py")
        compiler = importlib.util.module_from_spec(legacy_spec)
        legacy_spec.loader.exec_module(compiler)
        for name, content in compiler.build_outputs(self.root).items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        # The v2 compiler generates native skill links in main(), outside build_outputs.
        for runtime in (".codex", ".claude", ".agents"):
            p = self.root / runtime / "skills"
            p.parent.mkdir(parents=True, exist_ok=True)
            if not p.exists():
                p.symlink_to("../.ai/skills", target_is_directory=True)

    def snapshot(self):
        return {p.relative_to(self.root).as_posix(): t.read_asset(p) for p in t.paths_under(self.root)
                if not t.is_local(p.relative_to(self.root).as_posix())}

    def test_onboard_is_minimal_and_idempotent(self):
        self.onboard()
        self.assertFalse((self.root / ".ai/skills").exists())
        self.assertFalse((self.root / ".codex").exists())
        self.assertFalse((self.root / ".ai/generators").exists())
        before = self.snapshot()
        mtimes = {p: (self.root / p).stat().st_mtime_ns for p in before}
        self.onboard()
        self.assertEqual(before, self.snapshot())
        self.assertEqual(mtimes, {p: (self.root / p).stat().st_mtime_ns for p in before})
        self.assertEqual(t.doctor(REPO, self.root), [])
        self.assertLess(t.stats(self.root)["startup_tokens"], 450)

    def test_onboard_preserves_existing_project_and_native_skills(self):
        expected = {"AI.md": "Project invariants\n", ".claude/settings.json": '{"custom":true}\n',
                    ".agents/skills/local/SKILL.md": "Local skill\n", ".claude/settings.local.json": "private\n",
                    ".codex/local/session": "state\n", ".ai/context/conventions.md": "rules\n"}
        for p, text in expected.items(): self.put(p, text)
        self.onboard()
        for p, text in expected.items(): self.assertEqual((self.root / p).read_text(), text)
        self.assertNotIn(".claude/settings.json", t.load_state(self.root)["files"])

    def test_sync_preserves_modified_owned_files(self):
        self.onboard()
        self.put("AGENTS.md", "custom behavior\n")
        self.put("AI.md", "user project facts\n")
        (self.root / "CLAUDE.md").unlink()
        t.sync(REPO, self.root)
        self.assertEqual((self.root / "AGENTS.md").read_text(), "custom behavior\n")
        self.assertEqual((self.root / "AI.md").read_text(), "user project facts\n")
        self.assertTrue((self.root / "CLAUDE.md").is_file())
        self.assertIn("customized: AGENTS.md", t.doctor(REPO, self.root))

    def test_readonly_store_sources_create_writable_files(self):
        source = Path(self.tmp.name) / "source"
        shutil.copytree(REPO / "template", source / "template")
        shutil.copytree(REPO / "maintainer", source / "maintainer")
        for p in t.paths_under(source):
            p.chmod(0o555 if p.stat().st_mode & 0o111 else 0o444)
        t.sync(source, self.root, onboard=True)
        self.assertEqual((self.root / ".envrc").stat().st_mode & 0o777, 0o644)
        self.assertEqual((self.root / ".claude/hooks/statusline.sh").stat().st_mode & 0o777, 0o755)

    def test_roles_inherit_models_and_permissions(self):
        self.onboard()
        t.profile_command(REPO, self.root, "enable", "roles", None)
        for p in (self.root / ".codex/agents").glob("*.toml"):
            data = tomllib.loads(p.read_text())
            self.assertNotIn("model", data)
            self.assertNotIn("model_reasoning_effort", data)
            self.assertEqual(data["sandbox_mode"], "workspace-write" if p.stem == "worker" else "read-only")
        for p in (self.root / ".claude/agents").glob("*.md"):
            data = yaml.safe_load(p.read_text().split("---\n", 2)[1])
            self.assertNotIn("model", data)
            self.assertEqual(data["permissionMode"], "acceptEdits" if p.stem == "worker" else "plan")
        self.assertFalse((self.root / ".codex/config.toml").exists())
        self.assertGreater(t.stats(self.root)["role_descriptions_tokens"], 0)
        self.assertEqual(t.doctor(REPO, self.root), [])

    def test_explicit_model_overrides_survive_sync(self):
        self.onboard()
        path = self.put("overrides.json", json.dumps({"codex": {"worker": {"model": "chosen-model", "model_reasoning_effort": "low"}}, "claude": {"reviewer": {"model": "inherit"}}}))
        t.profile_command(REPO, self.root, "enable", "roles", path)
        t.sync(REPO, self.root)
        data = tomllib.loads((self.root / ".codex/agents/worker.toml").read_text())
        self.assertEqual(data["model"], "chosen-model")
        self.assertEqual(data["model_reasoning_effort"], "low")
        t.profile_command(REPO, self.root, "disable", "roles", None)
        self.assertEqual(t.load_state(self.root)["overrides"], {})

    def test_invalid_override_fails_before_changes(self):
        self.onboard()
        path = self.put("overrides.json", '{"codex":{"worker":{"sandbox_mode":"danger-full-access"}}}')
        before = self.snapshot()
        with self.assertRaises(t.Error): t.profile_command(REPO, self.root, "enable", "roles", path)
        self.assertEqual(before, self.snapshot())

    def test_optional_skills_discovery_and_disable(self):
        self.onboard()
        for name in ("agent-context", "frontend-design"):
            t.profile_command(REPO, self.root, "enable", f"skill:{name}", None)
            for runtime in (".agents", ".claude"):
                self.assertTrue((self.root / runtime / "skills" / name / "SKILL.md").is_file())
        self.assertGreater(t.stats(self.root)["skill_descriptions_tokens"], 0)
        t.profile_command(REPO, self.root, "disable", "skill:frontend-design", None)
        self.assertFalse((self.root / ".ai/skills/frontend-design").exists())
        self.assertTrue((self.root / ".agents/skills/agent-context/SKILL.md").is_file())

    def test_optional_skill_uses_existing_canonical_views(self):
        self.onboard()
        (self.root / ".agents").mkdir()
        (self.root / ".agents/skills").symlink_to("../.ai/skills")
        t.profile_command(REPO, self.root, "enable", "skill:agent-context", None)
        t.sync(REPO, self.root)
        self.assertTrue((self.root / ".agents/skills/agent-context/SKILL.md").is_file())

    def test_profile_enable_and_disable_are_atomic_on_custom_collision(self):
        self.onboard()
        self.put(".codex/agents/worker.toml", 'name = "custom"\n')
        before = self.snapshot()
        with self.assertRaises(t.Error): t.profile_command(REPO, self.root, "enable", "roles", None)
        self.assertEqual(before, self.snapshot())
        (self.root / ".codex/agents/worker.toml").unlink()
        t.profile_command(REPO, self.root, "enable", "roles", None)
        self.put(".codex/agents/worker.toml", 'name = "modified"\n')
        before = self.snapshot()
        with self.assertRaises(t.Error): t.profile_command(REPO, self.root, "disable", "roles", None)
        self.assertEqual(before, self.snapshot())

    def test_legacy_sync_never_upgrades(self):
        self.legacy()
        before = self.snapshot()
        for onboard in (True, False):
            with self.assertRaisesRegex(t.Error, "legacy project"): t.sync(REPO, self.root, onboard)
        self.assertEqual(before, self.snapshot())

    def test_migration_dryrun_and_restore(self):
        self.legacy()
        self.put("AI.md", "Exact user purpose and commands\n")
        self.put(".codex/local/state", "keep state\n")
        self.put(".claude/settings.local.json", "keep settings\n")
        before = self.snapshot()
        t.migrate(REPO, self.root, False)
        self.assertEqual(before, self.snapshot())
        self.assertFalse((self.root / ".ai/local").exists())
        t.migrate(REPO, self.root, True)
        self.assertEqual((self.root / "AI.md").read_text(), "Exact user purpose and commands\n")
        self.assertTrue((self.root / ".ai/context/legacy-project.yaml").is_file())
        self.assertFalse((self.root / ".ai/project.yaml").exists())
        self.assertFalse((self.root / ".codex/config.toml").exists())
        self.assertEqual(t.doctor(REPO, self.root), [])
        backup = next((self.root / ".ai/local/dev-template/backups").glob("*/backup.json"))
        self.assertEqual(backup.stat().st_mode & 0o777, 0o600)
        t.restore(self.root, backup)
        self.assertEqual(before, self.snapshot())
        self.assertEqual((self.root / ".codex/local/state").read_text(), "keep state\n")

    def test_migration_preserves_project_identity(self):
        self.legacy()
        p = self.root / ".ai/project.yaml"
        data = yaml.safe_load(p.read_text())
        data["project"] = {"name": "Real Product", "summary": "hard invariant", "extra": "specific project data"}
        p.write_text(yaml.safe_dump(data, sort_keys=False))
        t.migrate(REPO, self.root, True)
        self.assertEqual(yaml.safe_load((self.root / ".ai/context/legacy-project.yaml").read_text())["project"], data["project"])

    def test_migration_refuses_custom_core_without_mutation(self):
        for name in (".ai/policy.yaml", ".ai/generators/compile.py", "AGENTS.md"):
            with self.subTest(name=name):
                shutil.rmtree(self.root)
                self.root.mkdir()
                self.legacy()
                self.put(name, (self.root / name).read_text() + "\ncustom rule\n")
                before = self.snapshot()
                with self.assertRaises(t.Error): t.migrate(REPO, self.root, True)
                self.assertEqual(before, self.snapshot())

    def test_migration_refuses_custom_project_contract(self):
        self.legacy()
        p = self.root / ".ai/project.yaml"
        data = yaml.safe_load(p.read_text())
        data["context"]["always"].append("rules.md")
        p.write_text(yaml.safe_dump(data))
        before = self.snapshot()
        with self.assertRaisesRegex(t.Error, "custom project contract"): t.migrate(REPO, self.root, True)
        self.assertEqual(before, self.snapshot())

    def test_migration_preserves_customized_skill_as_whole_tree(self):
        self.legacy()
        self.put(".ai/skills/agent-context/references/custom.md", "Unique recurring process\n")
        before = {p.relative_to(self.root): t.read_asset(p) for p in t.paths_under(self.root / ".ai/skills/agent-context")}
        t.migrate(REPO, self.root, True)
        for p, a in before.items(): self.assertEqual(t.read_asset(self.root / p), a)
        self.assertTrue((self.root / ".agents/skills/agent-context/SKILL.md").is_file())

    def test_migration_preserves_catalog_activated_link_and_custom_role(self):
        self.legacy()
        self.put(".ai/catalog/local/SKILL.md", "Project skill\n")
        (self.root / ".ai/skills/local").symlink_to("../catalog/local")
        self.put(".ai/tools/custom.py", "# Project tool\n")
        self.put(".codex/agents/reviewer.toml", 'name = "custom-reviewer"\n')
        t.migrate(REPO, self.root, True)
        self.assertEqual((self.root / ".agents/skills/local/SKILL.md").read_text(), "Project skill\n")
        self.assertTrue((self.root / ".ai/tools/custom.py").is_file())
        self.assertEqual((self.root / ".codex/agents/reviewer.toml").read_text(), 'name = "custom-reviewer"\n')

    def test_restore_refuses_intervening_edit(self):
        self.onboard()
        backup = next((self.root / ".ai/local/dev-template/backups").glob("*/backup.json"))
        self.put("AGENTS.md", "new edit\n")
        before = self.snapshot()
        with self.assertRaisesRegex(t.Error, "changed since backup"): t.restore(self.root, backup)
        self.assertEqual(before, self.snapshot())

    def test_transaction_rolls_back_write_failure(self):
        self.onboard()
        before = self.snapshot()
        original = t.write_asset
        failed = False
        def fail_once(path, asset):
            nonlocal failed
            if path.name == "worker.toml" and not failed:
                failed = True
                raise OSError("injected disk failure")
            original(path, asset)
        with patch.object(t, "write_asset", fail_once):
            with self.assertRaisesRegex(OSError, "injected"):
                t.profile_command(REPO, self.root, "enable", "roles", None)
        self.assertTrue(failed)
        self.assertEqual(before, self.snapshot())

    def test_reset_preserves_local_state_and_source_and_restores(self):
        self.onboard()
        t.profile_command(REPO, self.root, "enable", "skill:agent-context", None)
        self.put("flake.nix", "# custom flake\n")
        self.put("flake.lock", "custom lock\n")
        self.put("AI.md", "custom AI\n")
        self.put(".ai/context/conventions.md", "old rules\n")
        self.put(".claude/settings.local.json", "private settings\n")
        self.put(".codex/tmp/scratch", "keep me\n")
        before = self.snapshot()
        t.reset(REPO, self.root, True, None)
        self.assertIn("rust-overlay", (self.root / "flake.nix").read_text())
        self.assertFalse((self.root / "flake.lock").exists())
        self.assertFalse((self.root / ".ai/skills").exists())
        self.assertEqual((self.root / ".codex/tmp/scratch").read_text(), "keep me\n")
        self.assertEqual((self.root / ".claude/settings.local.json").read_text(), "private settings\n")
        self.assertTrue((self.root / "Cargo.toml").is_file())
        backup = sorted((self.root / ".ai/local/dev-template/backups").glob("*/backup.json"))[-1]
        t.restore(self.root, backup)
        self.assertEqual(before, self.snapshot())

    def test_onboard_and_reset_reject_nonproject_directory(self):
        (self.root / "Cargo.toml").unlink()
        for fn in (lambda: self.onboard(), lambda: t.reset(REPO, self.root, True, None)):
            with self.assertRaisesRegex(t.Error, "project root"): fn()
        self.assertEqual(self.snapshot(), {})

    def test_reset_cancelled_without_changes(self):
        self.onboard()
        before = self.snapshot()
        with patch("builtins.input", return_value="no"):
            with self.assertRaisesRegex(t.Error, "cancelled"): t.reset(REPO, self.root, False, None)
        self.assertEqual(before, self.snapshot())

    def test_symlink_parent_cannot_write_outside_project(self):
        outside = Path(self.tmp.name) / "outside"
        outside.mkdir()
        (self.root / ".claude").symlink_to(outside)
        before = self.snapshot()
        with self.assertRaisesRegex(t.Error, "symlink"): self.onboard()
        self.assertEqual(before, self.snapshot())
        self.assertEqual(list(outside.iterdir()), [])

    def test_backup_symlink_cannot_write_outside_project(self):
        outside = Path(self.tmp.name) / "outside"
        outside.mkdir()
        (self.root / ".ai").mkdir()
        (self.root / ".ai/local").symlink_to(outside)
        before = self.snapshot()
        with self.assertRaisesRegex(t.Error, "symlink"): self.onboard()
        self.assertEqual(before, self.snapshot())
        self.assertEqual(list(outside.iterdir()), [])

    def test_unmanaged_skill_reference_prevents_partial_disable(self):
        self.onboard()
        t.profile_command(REPO, self.root, "enable", "skill:agent-context", None)
        self.put(".ai/skills/agent-context/references/project.md", "project-owned procedure")
        before = self.snapshot()
        with self.assertRaisesRegex(t.Error, "unmanaged skill file"):
            t.profile_command(REPO, self.root, "disable", "skill:agent-context", None)
        self.assertEqual(before, self.snapshot())

    def test_backups_are_ignored_even_without_root_gitignore(self):
        self.onboard()
        backup = next((self.root / ".ai/local/dev-template/backups").glob("*/backup.json"))
        self.assertEqual((backup.parent / ".gitignore").read_text(), "*\n")
        self.assertEqual(backup.parent.stat().st_mode & 0o777, 0o700)

    def test_doctor_validates_optional_knowledge_registry(self):
        self.onboard()
        self.put(".ai/context/knowledge-sources.yaml", "version: 1\nsources: []\n")
        with self.assertRaisesRegex(t.Error, "configured source"):
            t.doctor(REPO, self.root)

    def test_sync_updates_unchanged_owned_guidance(self):
        self.onboard()
        source = Path(self.tmp.name) / "source"
        shutil.copytree(REPO / "template", source / "template")
        shutil.copytree(REPO / "maintainer", source / "maintainer")
        p = source / "maintainer/guidance.md"
        p.write_text(p.read_text() + "\nUpdated shared instruction.\n")
        t.sync(source, self.root)
        self.assertIn("Updated shared instruction.", (self.root / "AGENTS.md").read_text())
        self.assertEqual(t.doctor(source, self.root), [])

    def test_disable_last_skill_keeps_existing_canonical_targets_valid(self):
        self.onboard()
        for runtime in (".agents", ".claude", ".codex"):
            (self.root / runtime).mkdir(exist_ok=True)
            (self.root / runtime / "skills").symlink_to("../.ai/skills")
        t.profile_command(REPO, self.root, "enable", "skill:agent-context", None)
        t.profile_command(REPO, self.root, "disable", "skill:agent-context", None)
        for runtime in (".agents", ".claude", ".codex"):
            self.assertTrue((self.root / runtime / "skills").is_dir())
        self.assertEqual(t.doctor(REPO, self.root), [])

    def test_doctor_checks_both_native_discovery_views(self):
        self.onboard()
        for runtime in (".agents", ".claude"):
            (self.root / runtime).mkdir(exist_ok=True)
            (self.root / runtime / "skills").symlink_to("../.ai/skills")
        issues = t.doctor(REPO, self.root)
        self.assertIn("broken skill link: .agents/skills", issues)
        self.assertIn("broken skill link: .claude/skills", issues)

    def test_corrupt_backup_assets_cannot_change_files(self):
        self.onboard()
        backup = next((self.root / ".ai/local/dev-template/backups").glob("*/backup.json"))
        original = json.loads(backup.read_text())
        invalid = [
            {"kind": "file", "data": "!!!", "mode": 0o644},
            {"kind": "file", "data": "", "mode": -1},
            {"kind": "file", "data": "", "mode": True},
            {"kind": "file", "data": "", "mode": 0o10000},
            {"kind": "link", "target": "safe", "unused": "value"},
            {"kind": "link", "target": ""},
            {"kind": "link", "target": "bad\0target"},
        ]
        before = self.snapshot()
        for asset in invalid:
            with self.subTest(asset=asset):
                record = json.loads(json.dumps(original))
                record["before"]["AGENTS.md"] = asset
                backup.write_text(json.dumps(record))
                with self.assertRaises(t.Error): t.restore(self.root, backup)
                self.assertEqual(before, self.snapshot())

    def test_backup_preserves_private_modes_and_custom_link_targets(self):
        path = self.put("AGENTS.md", "private old guidance")
        path.chmod(0o600)
        (self.root / "CLAUDE.md").symlink_to("/tmp/custom-guidance")
        backup = t.transaction(self.root, {"AGENTS.md": t.file_asset("replacement"), "CLAUDE.md": t.file_asset("replacement")}, "fixture")
        t.restore(self.root, backup)
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(os.readlink(self.root / "CLAUDE.md"), "/tmp/custom-guidance")

    def test_migration_retires_framework_cache_only_and_restores(self):
        self.legacy()
        cache = ".ai/generators/__pycache__/compile.cpython-314.pyc"
        self.put(cache, "legacy compiler bytecode")
        self.put(".ai/tools/__pycache__/custom.cpython-314.pyc", "project tool cache")
        before = self.snapshot()
        t.migrate(REPO, self.root, True)
        self.assertFalse((self.root / ".ai/generators").exists())
        self.assertEqual((self.root / ".ai/tools/__pycache__/custom.cpython-314.pyc").read_text(), "project tool cache")
        backup = next((self.root / ".ai/local/dev-template/backups").glob("*/backup.json"))
        t.restore(self.root, backup)
        self.assertEqual(before, self.snapshot())

    def old_catalog(self):
        fixture = json.loads((REPO / "tests/fixtures/v2-catalog.json").read_text())
        for name, asset in fixture["files"].items():
            t.write_asset(self.root / name, asset)

    def test_migration_retires_known_dormant_catalog_and_activation_cli(self):
        self.legacy()
        self.old_catalog()
        t.migrate(REPO, self.root, True)
        self.assertFalse((self.root / ".ai/catalog").exists())
        self.assertFalse((self.root / ".ai/tools/skillctl.py").exists())

    def test_migration_keeps_known_catalog_if_customized_or_activated(self):
        for activated in (True, False):
            with self.subTest(activated=activated):
                shutil.rmtree(self.root)
                self.root.mkdir()
                self.legacy()
                self.old_catalog()
                if activated:
                    (self.root / ".ai/skills/api-contracts").symlink_to("../catalog/api-contracts")
                else:
                    self.put(".ai/catalog/api-contracts/references/local.md", "project-owned advice")
                before = {p.relative_to(self.root): t.read_asset(p) for p in t.paths_under(self.root / ".ai/catalog")}
                t.migrate(REPO, self.root, True)
                for p, asset in before.items(): self.assertEqual(t.read_asset(self.root / p), asset)
                self.assertTrue((self.root / ".ai/tools/skillctl.py").is_file())
                if activated: self.assertTrue((self.root / ".agents/skills/api-contracts/SKILL.md").is_file())

    def test_broken_legacy_marker_blocks_onboarding_without_mutation(self):
        (self.root / ".ai").mkdir()
        (self.root / ".ai/project.yaml").symlink_to("missing-project.yaml")
        before = self.snapshot()
        with self.assertRaisesRegex(t.Error, "legacy project"): self.onboard()
        self.assertEqual(before, self.snapshot())

    def test_profile_rejects_external_provider_parent_even_with_canonical_link(self):
        self.onboard()
        outside = Path(self.tmp.name) / "outside"
        outside.mkdir()
        (outside / "skills").symlink_to("../.ai/skills")
        (self.root / ".agents").symlink_to(outside)
        before = self.snapshot()
        with self.assertRaisesRegex(t.Error, "symlink"):
            t.profile_command(REPO, self.root, "enable", "skill:agent-context", None)
        self.assertEqual(before, self.snapshot())

    def test_migration_preserves_catalog_for_custom_activation_cli(self):
        self.legacy()
        self.old_catalog()
        self.put(".ai/tools/skillctl.py", "# Project-specific activation behavior\n")
        t.migrate(REPO, self.root, True)
        self.assertTrue((self.root / ".ai/catalog/api-contracts/SKILL.md").is_file())
        self.assertEqual((self.root / ".ai/tools/skillctl.py").read_text(), "# Project-specific activation behavior\n")

    def test_migration_preserves_catalog_for_any_custom_project_tool(self):
        self.legacy()
        self.old_catalog()
        self.put(".ai/tools/project_activation.py", "# Uses catalog/api-contracts\n")
        t.migrate(REPO, self.root, True)
        self.assertTrue((self.root / ".ai/catalog/api-contracts/SKILL.md").is_file())
        self.assertTrue((self.root / ".ai/tools/project_activation.py").is_file())
        self.assertTrue((self.root / ".ai/tools/skillctl.py").is_file())

    def test_migration_preserves_direct_native_catalog_activation(self):
        self.legacy()
        self.old_catalog()
        p = self.root / ".agents/skills"
        p.unlink()
        p.mkdir()
        (p / "api-contracts").symlink_to("../../.ai/catalog/api-contracts")
        t.migrate(REPO, self.root, True)
        self.assertTrue((p / "api-contracts/SKILL.md").is_file())

    def test_malicious_ownership_is_rejected_before_changes(self):
        self.onboard()
        for name in ("../outside", "/tmp/outside", ".git/config", ".ai/local/state", "source.py"):
            with self.subTest(name=name):
                state = t.empty_state()
                state["files"][name] = {"hash": "0" * 64, "profile": "core"}
                self.put(t.STATE, json.dumps(state))
                before = self.snapshot()
                with self.assertRaises(t.Error): t.sync(REPO, self.root)
                self.assertEqual(before, self.snapshot())

    def test_doctor_rejects_malformed_state_and_detects_budget(self):
        self.onboard()
        self.put("AI.md", "x" * 5000)
        self.assertTrue(any("startup budget exceeded" in s for s in t.doctor(REPO, self.root)))
        self.put(t.STATE, "[]")
        with self.assertRaises(t.Error): t.doctor(REPO, self.root)


if __name__ == "__main__":
    unittest.main()
