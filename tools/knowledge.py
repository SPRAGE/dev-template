#!/usr/bin/env python3
"""Validate an optional project knowledge-source registry."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

import yaml


def load_yaml(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a YAML mapping")
    return data


def exact_keys(data: dict, expected: set[str], label: str) -> None:
    actual = set(data)
    if actual != expected:
        raise ValueError(f"{label} keys differ: missing={sorted(expected - actual)}, unused={sorted(actual - expected)}")


def validate_knowledge_registry(root: Path, relative: str) -> None:
    """Validate a schema-v1 optional registry below ``root``.

    A missing registry is valid: projects declare one only when a real source is
    configured. The relative-path guard prevents a registry declaration from
    escaping the project root.
    """
    if (
        not isinstance(relative, str)
        or not relative
        or relative != relative.strip()
        or not re.fullmatch(r"[A-Za-z0-9._/-]+", relative)
        or Path(relative).is_absolute()
        or ".." in Path(relative).parts
    ):
        raise ValueError("knowledge source registry path must be a safe project-relative path")
    registry_path = root / Path(relative)
    if not registry_path.exists():
        return
    registry = load_yaml(registry_path)
    exact_keys(registry, {"version", "sources"}, "knowledge source registry")
    if registry["version"] != 1:
        raise ValueError("knowledge source registry must use schema version 1")
    sources = registry["sources"]
    if not isinstance(sources, list) or not sources:
        raise ValueError("knowledge source registry must contain at least one configured source")
    ids: set[str] = set()
    logical_binding = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\Z")
    iso_duration = re.compile(r"P(?=\d|T\d)(?:\d+D)?(?:T(?:\d+H)?(?:\d+M)?(?:\d+S)?)?\Z")
    for position, source in enumerate(sources):
        label = f"knowledge source {position}"
        if not isinstance(source, dict):
            raise ValueError(f"{label} must be a mapping")
        exact_keys(
            source,
            {"id", "kind", "binding", "authority", "scope", "freshness", "access", "operations", "citation"},
            label,
        )
        source_id = source["id"]
        if not isinstance(source_id, str) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", source_id):
            raise ValueError(f"{label} has an invalid id")
        if source_id in ids:
            raise ValueError(f"knowledge source id is duplicated: {source_id}")
        ids.add(source_id)
        if not isinstance(source["kind"], str) or source["kind"] not in {
            "documentation", "code", "database", "tickets", "metrics", "other",
        }:
            raise ValueError(f"knowledge source {source_id} has an invalid kind")
        if not isinstance(source["binding"], str) or not logical_binding.fullmatch(source["binding"]):
            raise ValueError(f"knowledge source {source_id} binding must be an opaque local name")
        if not isinstance(source["authority"], str) or source["authority"] not in {"primary", "secondary", "advisory"}:
            raise ValueError(f"knowledge source {source_id} has an invalid authority")

        scope = source["scope"]
        if not isinstance(scope, dict):
            raise ValueError(f"knowledge source {source_id} scope must be a mapping")
        exact_keys(scope, {"domains", "tenant_isolation"}, f"knowledge source {source_id} scope")
        if not isinstance(scope["domains"], list) or not scope["domains"] or not all(
            isinstance(domain, str) and domain.strip() for domain in scope["domains"]
        ):
            raise ValueError(f"knowledge source {source_id} must declare non-empty domains")
        if len(scope["domains"]) != len(set(scope["domains"])):
            raise ValueError(f"knowledge source {source_id} domains must be unique")
        if not isinstance(scope["tenant_isolation"], str) or scope["tenant_isolation"] not in {
            "not_applicable", "source_enforced",
        }:
            raise ValueError(f"knowledge source {source_id} has an unsafe tenant isolation mode")

        freshness = source["freshness"]
        if not isinstance(freshness, dict):
            raise ValueError(f"knowledge source {source_id} freshness must be a mapping")
        exact_keys(freshness, {"max_age", "timestamp_field"}, f"knowledge source {source_id} freshness")
        max_age = freshness["max_age"]
        timestamp_field = freshness["timestamp_field"]
        if max_age is not None and (not isinstance(max_age, str) or not iso_duration.fullmatch(max_age)):
            raise ValueError(f"knowledge source {source_id} max_age must be an ISO-8601 day/time duration or null")
        if timestamp_field is not None and (
            not isinstance(timestamp_field, str) or not logical_binding.fullmatch(timestamp_field)
        ):
            raise ValueError(f"knowledge source {source_id} timestamp_field is invalid")
        if max_age is not None and timestamp_field is None:
            raise ValueError(f"knowledge source {source_id} needs a timestamp_field when max_age is set")

        access = source["access"]
        if not isinstance(access, dict):
            raise ValueError(f"knowledge source {source_id} access must be a mapping")
        exact_keys(access, {"classification", "authorization"}, f"knowledge source {source_id} access")
        if not isinstance(access["classification"], str) or access["classification"] not in {
            "public", "internal", "confidential", "restricted",
        }:
            raise ValueError(f"knowledge source {source_id} has an invalid classification")
        if not isinstance(access["authorization"], str) or access["authorization"] not in {
            "not_required", "source_enforced",
        }:
            raise ValueError(f"knowledge source {source_id} has an invalid authorization mode")
        if access["classification"] != "public" and access["authorization"] != "source_enforced":
            raise ValueError(f"knowledge source {source_id} must enforce access at the source")

        operations = source["operations"]
        if not isinstance(operations, dict):
            raise ValueError(f"knowledge source {source_id} operations must be a mapping")
        exact_keys(operations, {"search", "fetch", "mutate"}, f"knowledge source {source_id} operations")
        for operation in ("search", "fetch"):
            if not isinstance(operations[operation], str) or not logical_binding.fullmatch(operations[operation]):
                raise ValueError(f"knowledge source {source_id} needs a logical {operation} operation")
        if operations["mutate"] is not None and (
            not isinstance(operations["mutate"], str) or not logical_binding.fullmatch(operations["mutate"])
        ):
            raise ValueError(f"knowledge source {source_id} mutate operation is invalid")

        citation = source["citation"]
        if not isinstance(citation, dict):
            raise ValueError(f"knowledge source {source_id} citation must be a mapping")
        exact_keys(citation, {"id_field", "revision_field", "locator_field"}, f"knowledge source {source_id} citation")
        for field in ("id_field", "locator_field"):
            if not isinstance(citation[field], str) or not logical_binding.fullmatch(citation[field]):
                raise ValueError(f"knowledge source {source_id} citation {field} is invalid")
        if citation["revision_field"] is not None and (
            not isinstance(citation["revision_field"], str)
            or not logical_binding.fullmatch(citation["revision_field"])
        ):
            raise ValueError(f"knowledge source {source_id} citation revision_field is invalid")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("registry", help="safe project-relative registry path")
    args = parser.parse_args()
    try:
        validate_knowledge_registry(Path.cwd(), args.registry)
    except (OSError, UnicodeError, ValueError, yaml.YAMLError) as error:
        print(f"knowledge: {error}", file=sys.stderr)
        return 1
    print(f"knowledge registry valid or absent: {args.registry}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
