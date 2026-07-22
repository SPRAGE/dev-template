#!/usr/bin/env python3
"""Deterministic regression checks for neutral and generated agent contracts."""

from __future__ import annotations

import argparse
import importlib.util
import tomllib
from pathlib import Path

import yaml


GENERATED_MARKER = "Generated from .ai/ by .ai/generators/compile.py. Do not edit directly."


def load_module(path: Path):
    spec = importlib.util.spec_from_file_location("agent_compile", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_yaml(path: Path) -> dict:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise AssertionError(f"{path} is not a YAML mapping")
    return data


def parse_claude_agent(path: Path) -> tuple[dict, str]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise AssertionError(f"{path} has no YAML frontmatter")
    _, frontmatter, body = text.split("---\n", 2)
    metadata = yaml.safe_load(frontmatter)
    marker = f"<!-- {GENERATED_MARKER} -->\n\n"
    if marker not in body:
        raise AssertionError(f"{path} has no generated marker")
    return metadata, body.split(marker, 1)[1].rstrip()


def check_root(root: Path) -> None:
    ai = root / ".ai"
    compiler = load_module(ai / "generators/compile.py")
    project = load_yaml(ai / "project.yaml")
    policy = load_yaml(root / project["spec"]["policy"])
    capability_map = load_yaml(ai / "capabilities/map.yaml")
    profiles = load_yaml(ai / "capabilities/profiles.yaml")["profiles"]
    codex_runtime = load_yaml(ai / "capabilities/runtimes/codex.yaml")
    claude_runtime = load_yaml(ai / "capabilities/runtimes/claude.yaml")
    agents = [load_yaml(path) for path in sorted((ai / "agents").glob("*.yaml"))]

    expected_names = {agent["name"] for agent in agents}
    assert expected_names == {"scout", "researcher", "worker", "reviewer"}, (root, expected_names)
    codex_files = {path.stem.replace("-", "_") for path in (root / ".codex/agents").glob("*.toml")}
    claude_files = {path.stem.replace("-", "_") for path in (root / ".claude/agents").glob("*.md")}
    assert codex_files == expected_names, (root, codex_files ^ expected_names)
    assert claude_files == expected_names, (root, claude_files ^ expected_names)

    for agent in agents:
        filename = agent["name"].replace("_", "-")
        codex_data = tomllib.loads((root / ".codex/agents" / f"{filename}.toml").read_text(encoding="utf-8"))
        claude_data, claude_prompt = parse_claude_agent(root / ".claude/agents" / f"{filename}.md")
        neutral_profile = profiles[agent["profile"]]
        codex_profile = codex_runtime["profiles"][agent["profile"]]
        claude_profile = claude_runtime["profiles"][agent["profile"]]
        expected_prompt = compiler.agent_prompt(agent, capability_map, policy, neutral_profile.get("requires_human", False))

        assert codex_data["name"] == agent["name"]
        assert codex_data["model"] == codex_runtime["models"][agent["model_tier"]]["id"]
        assert codex_data["model_reasoning_effort"] == codex_runtime["reasoning_effort"][agent["name"]]
        assert codex_data["sandbox_mode"] == codex_profile["sandbox_mode"]
        assert codex_data["web_search"] == codex_profile["web_search"]
        assert codex_data["developer_instructions"].strip() == expected_prompt

        assert claude_data["name"] == filename
        assert claude_data["model"] == claude_runtime["models"][agent["model_tier"]]["id"]
        assert claude_data["permissionMode"] == claude_profile["permission_mode"]
        assert claude_data["maxTurns"] == claude_runtime["max_turns"][agent["name"]]
        actual_tools = [tool.strip() for tool in claude_data["tools"].split(",")]
        assert actual_tools == claude_profile["tools"]
        assert claude_prompt == expected_prompt
        assert codex_data["developer_instructions"].strip() == claude_prompt

        extensions = codex_runtime.get("agent_extensions", {}).get(agent["name"], {})
        assert codex_data.get("mcp_servers", {}) == extensions.get("mcp_servers", {})

    codex_config = tomllib.loads((root / ".codex/config.toml").read_text(encoding="utf-8"))
    orchestration = codex_runtime["orchestration"]
    assert "model" not in codex_config
    assert "review_model" not in codex_config
    assert codex_config["model_reasoning_effort"] == orchestration["main_reasoning_effort"]
    assert codex_config["plan_mode_reasoning_effort"] == orchestration["plan_mode_reasoning_effort"]
    assert codex_config["web_search"] == "disabled"
    assert codex_config["agents"]["max_threads"] == orchestration["max_threads"]
    assert codex_config["agents"]["max_depth"] == orchestration["max_depth"]
    assert "mcp_servers" not in codex_config


def check_shared_sources(repo: Path) -> None:
    base = repo / "template"
    roots = [repo, repo / "templates/python", repo / "templates/rust"]
    relative_paths = [
        ".ai/policy.yaml",
        ".ai/evals/contract-scenarios.yaml",
        ".ai/capabilities/map.yaml",
        ".ai/capabilities/profiles.yaml",
        ".ai/capabilities/runtimes/codex.yaml",
        ".ai/capabilities/runtimes/claude.yaml",
        ".ai/generators/compile.py",
    ]
    relative_paths.extend(
        path.relative_to(base).as_posix() for path in sorted((base / ".ai/agents").glob("*.yaml"))
    )
    for root in roots:
        for relative in relative_paths:
            assert (root / relative).read_bytes() == (base / relative).read_bytes(), f"shared spec drift: {root / relative}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    repo = args.repo.resolve()
    for root in (repo, repo / "template", repo / "templates/python", repo / "templates/rust"):
        check_root(root)
        print(f"PASS: provider contracts {root.relative_to(repo) or '.'}")
    check_shared_sources(repo)
    print("PASS: neutral source parity")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
