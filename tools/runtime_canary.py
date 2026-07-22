#!/usr/bin/env python3
"""Run zero-network runtime/config compatibility canaries."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import tomllib
from pathlib import Path

import yaml


GENERATED_MARKER = "Generated from .ai/ by .ai/generators/compile.py. Do not edit directly."
SAFE_INVOCATIONS = {
    "codex": {"version_args": ["--version"], "help_args": ["--help"]},
    "claude": {"version_args": ["--bare", "--version"], "help_args": ["--bare", "--help"]},
}


class CanaryError(ValueError):
    pass


def load_yaml(path: Path) -> dict:
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, yaml.YAMLError) as error:
        raise CanaryError(f"cannot read {path}: {error}") from error
    if not isinstance(data, dict):
        raise CanaryError(f"{path} must contain a YAML mapping")
    return data


def exact_keys(data: dict, expected: set[str], label: str) -> None:
    if not isinstance(data, dict) or set(data) != expected:
        actual = set(data) if isinstance(data, dict) else set()
        raise CanaryError(
            f"{label} keys differ: "
            f"missing={sorted(expected - actual, key=str)}, "
            f"unused={sorted(actual - expected, key=str)}"
        )


def command_output(command: str, arguments: list[str]) -> str:
    try:
        result = subprocess.run(
            [command, *arguments],
            check=True,
            capture_output=True,
            text=True,
            timeout=15,
        )
    except (OSError, UnicodeError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        raise CanaryError(f"offline command failed: {command} {' '.join(arguments)}: {error}") from error
    return result.stdout.strip() or result.stderr.strip()


def validate_cli_contract(config: dict) -> dict[str, str]:
    exact_keys(
        config,
        {"version", "network_behavior", "model_availability", "runtimes"},
        "runtime compatibility contract",
    )
    if type(config["version"]) is not int or config["version"] != 1 or config["network_behavior"] != "forbidden":
        raise CanaryError("runtime canary must remain version 1 and zero-network")
    if config["model_availability"] != "not_checked_offline":
        raise CanaryError("runtime canary must not imply remote model availability was checked")
    if not isinstance(config["runtimes"], dict) or set(config["runtimes"]) != {"codex", "claude"}:
        raise CanaryError("runtime canary must bind Codex and Claude")
    versions: dict[str, str] = {}
    for runtime, spec in config["runtimes"].items():
        exact_keys(
            spec,
            {"command", "version_args", "help_args", "tested_version", "version_pattern", "help_markers"},
            f"{runtime} canary",
        )
        if not isinstance(spec["command"], str) or not spec["command"].strip():
            raise CanaryError(f"{runtime} canary command must be a non-empty string")
        for field in ("version_args", "help_args", "help_markers"):
            values = spec[field]
            if (
                not isinstance(values, list)
                or not values
                or not all(isinstance(value, str) and value.strip() for value in values)
                or len(values) != len(set(values))
            ):
                raise CanaryError(f"{runtime} canary {field} must contain unique non-empty strings")
        expected_invocation = SAFE_INVOCATIONS[runtime]
        if spec["command"] != runtime or any(
            spec[field] != expected_invocation[field] for field in ("version_args", "help_args")
        ):
            raise CanaryError(f"{runtime} canary may invoke only its local version and help commands")
        if not isinstance(spec["version_pattern"], str) or not spec["version_pattern"]:
            raise CanaryError(f"{runtime} canary version pattern must be a non-empty string")
        if not isinstance(spec["tested_version"], str) or not spec["tested_version"]:
            raise CanaryError(f"{runtime} tested version must be a non-empty string")
        try:
            version_pattern = re.compile(spec["version_pattern"])
        except re.error as error:
            raise CanaryError(f"{runtime} canary version pattern is invalid: {error}") from error
        if version_pattern.groups != 1:
            raise CanaryError(f"{runtime} canary version pattern must capture exactly one version")
        version_output = command_output(spec["command"], spec["version_args"])
        match = version_pattern.fullmatch(version_output)
        if match is None:
            raise CanaryError(f"{runtime} returned an unexpected version string: {version_output!r}")
        actual_version = match.group(1)
        if actual_version != spec["tested_version"]:
            raise CanaryError(
                f"{runtime} version {actual_version} differs from tested {spec['tested_version']}; review before updating the canary"
            )
        help_output = command_output(spec["command"], spec["help_args"])
        missing = [marker for marker in spec["help_markers"] if marker not in help_output]
        if missing:
            raise CanaryError(f"{runtime} help contract lost markers: {missing}")
        versions[runtime] = actual_version
    return versions


def parse_claude_frontmatter(path: Path) -> dict:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        raise CanaryError(f"cannot read {path}: {error}") from error
    if not text.startswith("---\n") or "---\n" not in text[4:]:
        raise CanaryError(f"{path} has invalid YAML frontmatter")
    _, frontmatter, body = text.split("---\n", 2)
    try:
        metadata = yaml.safe_load(frontmatter)
    except yaml.YAMLError as error:
        raise CanaryError(f"cannot parse {path} frontmatter: {error}") from error
    if not isinstance(metadata, dict) or GENERATED_MARKER not in body:
        raise CanaryError(f"{path} is not a generated Claude role")
    return metadata


def validate_generated_root(root: Path) -> None:
    ai = root / ".ai"
    codex_runtime = load_yaml(ai / "capabilities/runtimes/codex.yaml")
    claude_runtime = load_yaml(ai / "capabilities/runtimes/claude.yaml")
    agents = [load_yaml(path) for path in sorted((ai / "agents").glob("*.yaml"))]
    if not agents:
        raise CanaryError(f"{root} has no neutral agent contracts")

    config_path = root / ".codex/config.toml"
    try:
        with config_path.open("rb") as handle:
            config = tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise CanaryError(f"cannot parse {config_path}: {error}") from error
    if "model" in config or "review_model" in config:
        raise CanaryError(f"{root} unexpectedly pins the primary model")

    for agent in agents:
        if not isinstance(agent.get("name"), str) or not isinstance(agent.get("model_tier"), str):
            raise CanaryError(f"{root} has an invalid neutral agent name or model tier")
        filename = agent["name"].replace("_", "-")
        codex_path = root / ".codex/agents" / f"{filename}.toml"
        try:
            with codex_path.open("rb") as handle:
                codex_agent = tomllib.load(handle)
            codex_text = codex_path.read_text(encoding="utf-8")
        except (OSError, UnicodeError, tomllib.TOMLDecodeError) as error:
            raise CanaryError(f"cannot parse {codex_path}: {error}") from error
        try:
            codex_model = codex_runtime["models"][agent["model_tier"]]["id"]
            claude_model = claude_runtime["models"][agent["model_tier"]]["id"]
        except (KeyError, TypeError) as error:
            raise CanaryError(f"{root} cannot bind model tier {agent['model_tier']}") from error
        if codex_agent.get("model") != codex_model or GENERATED_MARKER not in codex_text:
            raise CanaryError(f"{codex_path} model binding or ownership marker drifted")

        claude_path = root / ".claude/agents" / f"{filename}.md"
        claude_agent = parse_claude_frontmatter(claude_path)
        if claude_agent.get("model") != claude_model:
            raise CanaryError(f"{claude_path} model binding drifted")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument(
        "--contract",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "tests/runtime-compatibility.yaml",
    )
    args = parser.parse_args()
    try:
        repo = args.repo.resolve()
        versions = validate_cli_contract(load_yaml(args.contract.resolve()))
        for root in (repo, repo / "template", repo / "templates/python", repo / "templates/rust"):
            validate_generated_root(root)
            print(f"PASS: generated runtime contract {root.relative_to(repo) or '.'}")
        print(f"PASS: offline CLI canary codex={versions['codex']} claude={versions['claude']}")
        print("INFO: remote model availability not checked (zero-network canary)")
        return 0
    except CanaryError as error:
        print(f"runtime-canary: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
