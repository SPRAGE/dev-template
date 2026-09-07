#!/usr/bin/env python3
"""Regression tests for the standalone knowledge-source registry validator."""

from __future__ import annotations

import copy
import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

import yaml


REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("knowledge", REPO / "tools/knowledge.py")
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("cannot load tools/knowledge.py")
knowledge = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = knowledge
SPEC.loader.exec_module(knowledge)


def example_source() -> dict:
    return {
        "id": "product-docs",
        "kind": "documentation",
        "binding": "product-docs-read",
        "authority": "primary",
        "scope": {"domains": ["billing"], "tenant_isolation": "source_enforced"},
        "freshness": {"max_age": "P7D", "timestamp_field": "updated_at"},
        "access": {"classification": "internal", "authorization": "source_enforced"},
        "operations": {"search": "search", "fetch": "fetch", "mutate": None},
        "citation": {"id_field": "document_id", "revision_field": "revision", "locator_field": "url"},
    }


class KnowledgeRegistryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.relative = ".ai/context/knowledge-sources.yaml"

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write(self, sources: list[dict]) -> None:
        path = self.root / self.relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(yaml.safe_dump({"version": 1, "sources": sources}, sort_keys=False), encoding="utf-8")

    def test_valid_registry_and_absent_optional_path(self) -> None:
        knowledge.validate_knowledge_registry(self.root, self.relative)
        self.write([example_source()])
        knowledge.validate_knowledge_registry(self.root, self.relative)

    def test_duplicate_identifier_is_rejected(self) -> None:
        source = example_source()
        self.write([source, copy.deepcopy(source)])
        with self.assertRaisesRegex(ValueError, "duplicated"):
            knowledge.validate_knowledge_registry(self.root, self.relative)

    def test_endpoint_like_binding_is_rejected(self) -> None:
        source = example_source()
        source["binding"] = "https://source.invalid/registry"
        self.write([source])
        with self.assertRaisesRegex(ValueError, "opaque local name"):
            knowledge.validate_knowledge_registry(self.root, self.relative)

    def test_nonpublic_source_requires_source_enforced_authorization(self) -> None:
        source = example_source()
        source["access"]["authorization"] = "not_required"
        self.write([source])
        with self.assertRaisesRegex(ValueError, "enforce access"):
            knowledge.validate_knowledge_registry(self.root, self.relative)

    def test_bad_freshness_is_rejected(self) -> None:
        for freshness, error in (
            ({"max_age": "seven days", "timestamp_field": "updated_at"}, "ISO-8601"),
            ({"max_age": "P7D", "timestamp_field": None}, "needs a timestamp_field"),
        ):
            with self.subTest(freshness=freshness):
                source = example_source()
                source["freshness"] = freshness
                self.write([source])
                with self.assertRaisesRegex(ValueError, error):
                    knowledge.validate_knowledge_registry(self.root, self.relative)

    def test_unsafe_registry_paths_are_rejected(self) -> None:
        for relative in ("../knowledge-sources.yaml", "/tmp/knowledge-sources.yaml", "registry\nignore"):
            with self.subTest(relative=relative):
                with self.assertRaisesRegex(ValueError, "safe project-relative"):
                    knowledge.validate_knowledge_registry(self.root, relative)


if __name__ == "__main__":
    unittest.main()
