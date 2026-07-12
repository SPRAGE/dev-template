#!/usr/bin/env python3
"""Compile the neutral agent specification into Codex and Claude artifacts."""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

import yaml


GENERATED_MARKER = "Generated from .ai/ by .ai/generators/compile.py. Do not edit directly."


def load_yaml(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a YAML mapping")
    return data


def estimate_tokens(text: str) -> int:
    words = len(re.findall(r"\S+", text))
    return math.ceil(max(len(text.encode("utf-8")) / 4, words * 1.3))


def toml_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def words(values: list[str], conjunction: str = "or") -> str:
    rendered = [value.replace("_", " ") for value in values]
    if len(rendered) < 2:
        return "".join(rendered)
    if len(rendered) == 2:
        return f"{rendered[0]} {conjunction} {rendered[1]}"
    return f"{', '.join(rendered[:-1])}, {conjunction} {rendered[-1]}"


def repository_scope_phrase(value: str) -> str:
    phrases = {
        "current_git_root": "current Git root",
        "explicit_external_path": "the user explicitly names its path",
        "explicit_cross_repository_authorization": "explicitly authorizes cross-repository work",
        "inspect_authorized_repository": "Limit access to the named or authorized repositories.",
        "report_repository_boundary": (
            "report that it is outside the current repository boundary and request a path or authorization"
        ),
    }
    try:
        return phrases[value]
    except KeyError as error:
        raise ValueError(f"repository scope uses unknown value: {value}") from error


def unique(values: list[str]) -> list[str]:
    return list(dict.fromkeys(values))


def agent_prompt(agent: dict, capability_map: dict, policy: dict, requires_human: bool = False) -> str:
    inputs = unique(
        [
            field
            for capability in agent["capabilities"]
            for field in capability_map["capabilities"][capability]["inputs"]
        ]
    )
    outputs = capability_map["output_contracts"]
    fields = unique(outputs["common"]["fields"] + outputs[agent["output_contract"]]["fields"])
    completion = policy["completion"]
    constraints = "\n".join(f"- {item}" for item in agent.get("constraints", []))
    if requires_human:
        constraints += "\n- Obtain explicit approval before any privileged, destructive, or external action."
    write_scope = agent.get("write_scope")
    scope_line = f"\nWrite scope: {write_scope}" if write_scope else ""
    return (
        f"Mission: {agent['mission']}{scope_line}\n\n"
        f"Use when: {agent['when_to_use']}\n"
        f"Avoid when: {agent['avoid_when']}\n\n"
        f"Task context: {', '.join(inputs)}. Derive only reversible missing facts from repository evidence; "
        "otherwise return blocked instead of expanding scope.\n\n"
        f"Constraints:\n{constraints}\n\n"
        f"Return a structured report with these fields: {', '.join(fields)}. Lead with status and the decision, "
        "then evidence and material caveats; omit raw logs and repeated background. "
        f"Status is one of {', '.join(completion['statuses'])}. Complete requires "
        f"{', '.join(completion['complete_requires'])}; partial requires "
        f"{', '.join(completion['partial_requires'])}; blocked requires "
        f"{', '.join(completion['blocked_requires'])}."
    )


def render_codex_agent(agent: dict, runtime: dict, capability_map: dict, policy: dict, neutral_profile: dict) -> str:
    model = runtime["models"][agent["model_tier"]]
    profile = runtime["profiles"][agent["profile"]]
    prompt = agent_prompt(agent, capability_map, policy, neutral_profile.get("requires_human", False))
    description = f"{agent['mission']} Use when: {agent['when_to_use']} Avoid when: {agent['avoid_when']}"
    lines = [
        f"# {GENERATED_MARKER}",
        f"name = {toml_string(agent['name'])}",
        f"description = {toml_string(description)}",
        f"model = {toml_string(model['id'])}",
        f"model_reasoning_effort = {toml_string(runtime['reasoning_effort'][agent['name']])}",
        f"sandbox_mode = {toml_string(profile['sandbox_mode'])}",
        f"web_search = {toml_string(profile['web_search'])}",
        f"nickname_candidates = [{toml_string(agent['name'].replace('_', ' ').title())}]",
        'developer_instructions = """',
        prompt,
        '"""',
    ]
    extension = runtime.get("agent_extensions", {}).get(agent["name"], {})
    for server, settings in extension.get("mcp_servers", {}).items():
        lines += ["", f"[mcp_servers.{server}]"]
        lines.extend(f"{key} = {toml_string(value)}" for key, value in settings.items())
    return "\n".join(lines) + "\n"


def render_claude_agent(agent: dict, runtime: dict, capability_map: dict, policy: dict, neutral_profile: dict) -> str:
    model = runtime["models"][agent["model_tier"]]
    profile = runtime["profiles"][agent["profile"]]
    name = agent["name"].replace("_", "-")
    tools = ", ".join(profile["tools"])
    prompt = agent_prompt(agent, capability_map, policy, neutral_profile.get("requires_human", False))
    description = f"{agent['mission']} Use when: {agent['when_to_use']} Avoid when: {agent['avoid_when']}"
    return (
        "---\n"
        f"name: {name}\n"
        f"description: {json.dumps(description)}\n"
        f"tools: {tools}\n"
        f"model: {model['id']}\n"
        f"permissionMode: {profile['permission_mode']}\n"
        f"maxTurns: {agent['max_turns']}\n"
        "---\n\n"
        f"<!-- {GENERATED_MARKER} -->\n\n"
        f"{prompt}\n"
    )


def render_codex_config(runtime: dict) -> str:
    orch = runtime["orchestration"]
    main = runtime["models"][orch["main_model_tier"]]
    review = runtime["models"][orch["review_model_tier"]]
    return f"""# {GENERATED_MARKER}
project_doc_max_bytes = 16384
project_doc_fallback_filenames = ["AI.md"]
model = "{main['id']}"
model_reasoning_effort = "{orch['main_reasoning_effort']}"
plan_mode_reasoning_effort = "{orch['plan_mode_reasoning_effort']}"
review_model = "{review['id']}"
web_search = "disabled"
personality = "{orch['personality']}"

[features]
multi_agent = true

[agents]
max_threads = {orch['max_threads']}
max_depth = {orch['max_depth']}
"""


def render_adapter(runtime: str, runtime_spec: dict) -> str:
    shared = (
        "Read `AI.md` and `.ai/instructions.md`. For work that is not Direct, also read ".strip()
        + " `.ai/methodology.md`. Load `.ai/context/` files only through the routes in the shared instructions."
    )
    fallback = runtime_spec["fallback"]
    if fallback != "inline_and_report_limitation":
        raise ValueError(f"unsupported runtime fallback: {fallback}")
    fallback_note = "If a mapped runtime capability is unavailable, execute it inline and state the limitation."
    if runtime == "codex":
        notes = (
            "Codex discovers skills through `.agents/skills/` and custom agents through `.codex/agents/`. "
            "Preserve `.codex/local/` and `.codex/tmp/`."
        )
        return f"# Codex Adapter\n\n<!-- {GENERATED_MARKER} -->\n\n{shared}\n\n{notes} {fallback_note}\n"
    notes = (
        "Claude Code discovers skills through `.claude/skills/` and project subagents through `.claude/agents/`. "
    )
    return f"# Claude Code Adapter\n\n<!-- {GENERATED_MARKER} -->\n\n{shared}\n\n{notes}{fallback_note}\n"


def render_instructions(policy: dict, project: dict) -> str:
    authorization = policy["authorization"]
    repository_scope = policy["repository_scope"]
    delivery = policy["delivery"]
    completion = policy["completion"]
    context = project["context"]
    inspect_intents = words(authorization["inspect_intents"])
    change_intents = words(authorization["change_intents"])
    confirm_before = words(authorization["confirm_before"])
    question_trigger = words(authorization["question_trigger"])
    preserve = words(completion["preserve"], "and")
    prohibited = words(completion["prohibited_shortcuts"])
    planned_triggers = words(delivery["planned"]["when_any"])
    hard_triggers = words(delivery["hard"]["when_any"])
    scope_boundary = repository_scope_phrase(repository_scope["default_boundary"])
    scope_authorization = words(
        [repository_scope_phrase(value) for value in repository_scope["allow_cross_repository_when"]]
    )
    scope_action = repository_scope_phrase(repository_scope["authorized_action"])
    absent_scope_action = repository_scope_phrase(repository_scope["absent_code_action"])
    return f"""# Agent Instructions

<!-- {GENERATED_MARKER} -->

## Context Routing

- Always read {', '.join(f'`{path}`' for path in context['always'])}.
- Read `{context['conditional']['architecture']}` before architectural or cross-boundary work and `{context['conditional']['conventions']}` before edits or review.
- Read `{context['conditional']['decisions']}` only when the task touches a recorded choice; read `{context['conditional']['active']}` only when it exists and contains current work.
- Load a skill body only when its description matches the task or the user names it.

## Authorization

- For {inspect_intents} requests, inspect and report only. Do not edit or advance into implementation unless asked.
- For {change_intents} requests, make in-scope local changes and run non-destructive validation without repeated confirmation.
- Confirm immediately before {confirm_before}. Ask a question only when repository evidence cannot resolve a {question_trigger}.

## Repository Boundary

- Limit repository search, file reads, and version-control inspection to the {scope_boundary}.
- Inspect another repository only when {scope_authorization}. {scope_action}
- If requested code is absent, {absent_scope_action}. Do not discover or search sibling directories.

## Delivery

1. Inspect the working state, relevant code, documented commands, and generated/source boundaries.
2. Execute a bounded, reversible, low-risk task directly with focused verification, even when the mechanical edit spans files.
3. Read `.ai/methodology.md` and use one deep plan when work involves {planned_triggers}.
4. Use the Hard route when work involves {hard_triggers}. Require deep planning, staged evidence, and independent deep risk review.
5. Reuse and update the accepted plan; do not restart discovery or silently change layers. Delegate only ready, bounded steps and parallelize only independent work.

## Preservation

Treat user-stated values and existing in-scope behavior as acceptance criteria. Preserve {preserve}. Never {prohibited}.

## Completion

Use lifecycle status {words(completion['statuses'])}. Complete requires {words(completion['complete_requires'], 'and')}; partial requires {words(completion['partial_requires'], 'and')}; blocked requires {words(completion['blocked_requires'], 'and')}. Report the outcome, evidence, material caveat, and next action. Never claim completion without evidence or an explicit verification limitation.
"""


def render_methodology(policy: dict) -> str:
    delivery = policy["delivery"]
    routing = policy["routing"]
    handoff = policy["handoff"]
    direct = words(delivery["direct"]["when_all"], "and")
    planned = words(delivery["planned"]["when_any"])
    hard = words(delivery["hard"]["when_any"])
    required = ", ".join(f"`{field}`" for field in handoff["required"])
    stop_on = words(handoff["stop_on"])
    return f"""# Delivery Method

<!-- {GENERATED_MARKER} -->

Use the smallest route that can produce evidence without losing the user's intent.

## Routes

- **Direct:** {direct}. The primary agent executes and runs a focused check; no formal plan or independent review is required.
- **Planned:** any of {planned}. The {delivery['planned']['planner_tier']} tier creates one implementation-ready plan, the {delivery['planned']['worker_tier']} tier executes bounded code steps, and the {delivery['planned']['review_tier']} tier performs routine independent review.
- **Hard:** any of {hard}. The {delivery['hard']['planner_tier']} tier owns planning and the {delivery['hard']['review_tier']} tier performs independent risk review. Use staged gates when a later action is destructive or external.

File count alone does not select Planned. Prefer Direct for mechanical, reversible changes whose dependencies and success criteria are already clear.

## Plan Contract

The planner stays in the planning layer. It returns the objective, task mode, material assumptions, success criteria, preserved invariants, dependency-ordered steps with file ownership, risks, required verification, and stop conditions. A small prompt should be expanded from repository evidence, not from invented requirements.

Reuse the accepted plan. Update only the affected steps when evidence changes; do not make workers rediscover the repository or silently move from explanation/planning into implementation.

## Handoff Contract

Every worker handoff supplies {required}. If repository evidence cannot safely fill a missing item, return blocked. Stop on {stop_on}; never redesign silently or expand the approved scope.

Route exploration and primary-source research to the {routing['explore']}/{routing['research']} tiers, bounded implementation and integration to the {routing['implement']}/{routing['integrate']} tiers, tests and documentation to the {routing['test']}/{routing['document']} tiers, routine review to the {routing['review']} tier, and high-consequence review to the {routing['risk_review']} tier. Expose network and MCP tools only to the research role that needs them.

## Integrate And Prove

Use an integrator only for multiple worker results, conflicts, or material integration risk. Re-read the current diff, reconcile results against success criteria and preserved invariants, run risk-appropriate checks, and request the routed independent review. Return distilled evidence rather than raw logs.
"""


def render_capability_map(data: dict) -> str:
    lines = [f"# Capability Map\n\n<!-- {GENERATED_MARKER} -->\n", "| Capability | Profile | Inputs | Output |", "|---|---|---|---|"]
    for name, spec in data["capabilities"].items():
        lines.append(f"| `{name}` | `{spec['profile']}` | {', '.join(spec['inputs'])} | `{spec['output']}` |")
    lines.append("\nIf a mapped runtime capability is unavailable, execute inline and state the limitation.")
    return "\n".join(lines) + "\n"


def populated(value: object) -> bool:
    return value is not None and value != "" and value != [] and value != {}


def exact_keys(data: dict, expected: set[str], label: str) -> None:
    actual = set(data)
    if actual != expected:
        raise ValueError(f"{label} keys differ: missing={sorted(expected - actual)}, unused={sorted(actual - expected)}")


def validate_policy(policy: dict, capability_map: dict) -> None:
    exact_keys(
        policy,
        {
            "version",
            "authorization",
            "repository_scope",
            "delivery",
            "routing",
            "handoff",
            "completion",
        },
        "policy",
    )
    for section in ("authorization", "delivery", "routing", "handoff", "completion"):
        if section not in policy:
            raise ValueError(f"policy is missing {section}")
    authorization = policy["authorization"]
    exact_keys(
        authorization,
        {"inspect_intents", "change_intents", "inspect_action", "change_action", "confirm_before", "question_trigger"},
        "authorization policy",
    )
    if set(authorization["inspect_intents"]) & set(authorization["change_intents"]):
        raise ValueError("inspect and change intents must not overlap")
    exact_keys(
        policy["repository_scope"],
        {
            "default_boundary",
            "allow_cross_repository_when",
            "authorized_action",
            "absent_code_action",
        },
        "repository scope policy",
    )
    delivery = policy["delivery"]
    if set(delivery) != {"direct", "planned", "hard"}:
        raise ValueError("delivery routes must be direct, planned, and hard")
    if set(delivery["planned"]["when_any"]) & set(delivery["hard"]["when_any"]):
        raise ValueError("planned and hard triggers must be deterministic")
    valid_tiers = {"none", "primary", "fast", "balanced", "deep"}
    for name, route in delivery.items():
        trigger_key = "when_all" if name == "direct" else "when_any"
        exact_keys(route, {trigger_key, "planner_tier", "worker_tier", "review_tier"}, f"{name} delivery route")
        for field in ("planner_tier", "worker_tier", "review_tier"):
            if route[field] not in valid_tiers:
                raise ValueError(f"unknown {field}: {route[field]}")
    if set(policy["routing"].values()) - {"fast", "balanced", "deep"}:
        raise ValueError("capability routing uses an unknown model tier")
    completion = policy["completion"]
    exact_keys(
        policy["handoff"],
        {"required", "stop_on"},
        "handoff policy",
    )
    exact_keys(
        completion,
        {
            "statuses",
            "complete_requires",
            "partial_requires",
            "blocked_requires",
            "preserve",
            "prohibited_shortcuts",
        },
        "completion policy",
    )
    exact_keys(capability_map, {"version", "capabilities", "output_contracts"}, "capability map")
    for name, capability in capability_map["capabilities"].items():
        exact_keys(capability, {"profile", "inputs", "output"}, f"capability {name}")
    for name, contract in capability_map["output_contracts"].items():
        exact_keys(contract, {"fields"}, f"output contract {name}")
    common_fields = set(capability_map["output_contracts"]["common"]["fields"])
    required_fields = set(
        completion["complete_requires"]
        + completion["partial_requires"]
        + completion["blocked_requires"]
    )
    if required_fields - common_fields:
        raise ValueError(f"completion fields missing from common output: {sorted(required_fields - common_fields)}")
    if set(completion["statuses"]) != {"complete", "partial", "blocked"}:
        raise ValueError("completion statuses must be complete, partial, and blocked")


def evaluate_route(policy: dict, case: dict) -> dict:
    inputs = case["input"]
    authorization = policy["authorization"]
    action_flags = set(inputs.get("action_flags", []))
    if action_flags & set(authorization["confirm_before"]):
        action = "confirm_before_action"
    elif inputs["intent"] in authorization["inspect_intents"]:
        action = authorization["inspect_action"]
    elif inputs["intent"] in authorization["change_intents"]:
        action = authorization["change_action"]
    else:
        raise ValueError(f"scenario {case['id']} uses unknown intent {inputs['intent']}")

    flags = set(inputs.get("delivery_flags", []))
    delivery = policy["delivery"]
    known_flags = set(delivery["planned"]["when_any"]) | set(delivery["hard"]["when_any"])
    if flags - known_flags:
        raise ValueError(f"scenario {case['id']} uses unknown delivery flags: {sorted(flags - known_flags)}")
    if flags & set(delivery["hard"]["when_any"]):
        route_name = "hard"
    elif flags & set(delivery["planned"]["when_any"]):
        route_name = "planned"
    else:
        route_name = "direct"
    route = delivery[route_name]
    may_execute = action == authorization["change_action"]
    return {
        "authorization": action,
        "delivery": route_name,
        "planner_tier": route["planner_tier"],
        "worker_tier": route["worker_tier"] if may_execute else "none",
        "review_tier": route["review_tier"] if may_execute else "none",
    }


def evaluate_repository_scope(policy: dict, case: dict) -> str:
    repository_scope = policy["repository_scope"]
    flags = set(case["input"].get("authorization_flags", []))
    allowed_flags = set(repository_scope["allow_cross_repository_when"])
    if flags - allowed_flags:
        raise ValueError(
            f"repository-scope scenario {case['id']} uses unknown flags: {sorted(flags - allowed_flags)}"
        )
    if flags & allowed_flags:
        return repository_scope["authorized_action"]
    return repository_scope["absent_code_action"]


def validate_report(policy: dict, capability_map: dict, case: dict) -> bool:
    report = case["report"]
    completion = policy["completion"]
    status = report.get("status")
    if status not in completion["statuses"]:
        return False
    required = completion[f"{status}_requires"]
    if any(not populated(report.get(field)) for field in required):
        return False
    if status == "complete":
        contracts = capability_map["output_contracts"]
        required_fields = unique(contracts["common"]["fields"] + contracts[case["contract"]]["fields"])
        if any(field not in report for field in required_fields):
            return False
    return True


def validate_scenarios(policy: dict, capability_map: dict, scenarios: dict) -> None:
    required_routes = {
        "explain_code",
        "plan_dependent_feature",
        "fix_local_bug",
        "mechanical_cross_file_change",
        "build_dependent_feature",
        "fix_security_migration",
        "delete_data",
        "publish_release",
    }
    route_cases = scenarios.get("routing", [])
    route_ids = {case["id"] for case in route_cases}
    if required_routes - route_ids:
        raise ValueError(f"contract evals missing routing cases: {sorted(required_routes - route_ids)}")
    for case in route_cases:
        actual = evaluate_route(policy, case)
        if actual != case["expect"]:
            raise ValueError(f"routing scenario {case['id']} expected {case['expect']}, got {actual}")

    required_scope_cases = {
        "code_absent_from_current_repo",
        "user_names_external_repo",
        "user_authorizes_cross_repo_search",
    }
    scope_cases = scenarios.get("repository_scope", [])
    scope_case_ids = {case["id"] for case in scope_cases}
    if required_scope_cases - scope_case_ids:
        raise ValueError(
            f"contract evals missing repository-scope cases: {sorted(required_scope_cases - scope_case_ids)}"
        )
    for case in scope_cases:
        actual = evaluate_repository_scope(policy, case)
        if actual != case["expect"]:
            raise ValueError(
                f"repository-scope scenario {case['id']} expected {case['expect']}, got {actual}"
            )

    report_cases = scenarios.get("reports", [])
    required_reports = {
        "complete_with_evidence",
        "complete_without_evidence",
        "blocked_with_stop_reason",
        "scope_conflict_blocks",
        "blocked_without_stop_reason",
    }
    report_ids = {case["id"] for case in report_cases}
    if required_reports - report_ids:
        raise ValueError(f"contract evals missing report cases: {sorted(required_reports - report_ids)}")
    for case in report_cases:
        actual = validate_report(policy, capability_map, case)
        if actual is not case["valid"]:
            raise ValueError(f"report scenario {case['id']} expected valid={case['valid']}, got {actual}")


def validate_runtime_profiles(neutral: dict, codex: dict, claude: dict) -> None:
    exact_keys(
        codex,
        {"version", "runtime", "models", "profiles", "orchestration", "reasoning_effort", "agent_extensions", "fallback"},
        "Codex runtime",
    )
    exact_keys(claude, {"version", "runtime", "models", "profiles", "fallback"}, "Claude runtime")
    if codex["runtime"] != "codex" or claude["runtime"] != "claude":
        raise ValueError("runtime identifiers do not match their binding files")
    exact_keys(
        codex["orchestration"],
        {
            "main_model_tier",
            "main_reasoning_effort",
            "review_model_tier",
            "max_threads",
            "max_depth",
            "plan_mode_reasoning_effort",
            "personality",
        },
        "Codex orchestration",
    )
    names = set(neutral)
    if set(codex["profiles"]) != names or set(claude["profiles"]) != names:
        raise ValueError("runtime profile names must exactly match neutral profiles")
    for name, profile in neutral.items():
        neutral_keys = {"filesystem", "write", "network"}
        if "requires_human" in profile:
            neutral_keys.add("requires_human")
        exact_keys(profile, neutral_keys, f"neutral profile {name}")
        codex_profile = codex["profiles"][name]
        claude_profile = claude["profiles"][name]
        codex_keys = {"sandbox_mode", "web_search"}
        if "requires_human" in codex_profile:
            codex_keys.add("requires_human")
        exact_keys(codex_profile, codex_keys, f"Codex profile {name}")
        exact_keys(claude_profile, {"permission_mode", "tools"}, f"Claude profile {name}")
        if profile["filesystem"] not in {"read", "workspace"}:
            raise ValueError(f"neutral profile {name} has unknown filesystem scope")
        if profile["write"] not in {False, True, "tests_and_diagnostics"}:
            raise ValueError(f"neutral profile {name} has unknown write scope")
        if not isinstance(profile["network"], bool):
            raise ValueError(f"neutral profile {name} network must be boolean")
        if codex_profile["sandbox_mode"] not in {"read-only", "workspace-write"}:
            raise ValueError(f"Codex profile {name} has unknown sandbox mode")
        if codex_profile["web_search"] not in {"disabled", "live"}:
            raise ValueError(f"Codex profile {name} has unknown web-search mode")
        if claude_profile["permission_mode"] not in {"plan", "acceptEdits", "default"}:
            raise ValueError(f"Claude profile {name} has unknown permission mode")
        network = profile["network"]
        if codex_profile["web_search"] != ("live" if network else "disabled"):
            raise ValueError(f"Codex profile {name} does not preserve network scope")
        if not profile["write"] and codex_profile["sandbox_mode"] != "read-only":
            raise ValueError(f"Codex profile {name} broadens read-only filesystem scope")
        claude_tools = set(claude_profile["tools"])
        if not profile["write"] and claude_tools & {"Edit", "Write"}:
            raise ValueError(f"Claude profile {name} broadens read-only filesystem scope")
        if profile["write"] is True and not {"Edit", "Write"}.issubset(claude_tools):
            raise ValueError(f"Claude profile {name} cannot perform declared writes")
        if network != bool(claude_tools & {"WebFetch", "WebSearch"}):
            raise ValueError(f"Claude profile {name} does not preserve network scope")
        requires_human = profile.get("requires_human", False)
        if codex_profile.get("requires_human", False) != requires_human:
            raise ValueError(f"Codex profile {name} loses the human confirmation boundary")
        if requires_human and claude_profile["permission_mode"] != "default":
            raise ValueError(f"Claude profile {name} must retain normal approval prompts")


def validate_agents(agents: list[dict], capability_map: dict, profiles: dict, policy: dict, codex: dict, claude: dict) -> None:
    known_capabilities = set(capability_map["capabilities"])
    outputs = capability_map["output_contracts"]
    names = {agent["name"] for agent in agents}
    if len(names) != len(agents):
        raise ValueError("agent names must be unique")
    if set(codex["reasoning_effort"]) != names:
        raise ValueError("Codex reasoning_effort must bind every agent exactly once")
    unknown_extensions = set(codex.get("agent_extensions", {})) - names
    if unknown_extensions:
        raise ValueError(f"Codex extensions reference unknown agents: {sorted(unknown_extensions)}")
    for name, extension in codex.get("agent_extensions", {}).items():
        exact_keys(extension, {"mcp_servers"}, f"Codex extension {name}")
        for server, settings in extension["mcp_servers"].items():
            exact_keys(settings, {"url"}, f"Codex MCP server {server}")
    allowed_efforts = {"none", "low", "medium", "high", "xhigh", "max"}
    if set(codex["reasoning_effort"].values()) - allowed_efforts:
        raise ValueError("Codex agent reasoning_effort contains an unsupported value")
    for runtime in (codex, claude):
        if set(runtime["models"]) != {"deep", "balanced", "fast"}:
            raise ValueError(f"{runtime['runtime']} must bind deep, balanced, and fast model tiers")
        for tier, model in runtime["models"].items():
            if set(model) != {"id"}:
                raise ValueError(f"{runtime['runtime']} model tier {tier} has unused fields")
    for agent in agents:
        allowed_fields = {
            "version",
            "name",
            "mission",
            "when_to_use",
            "avoid_when",
            "capabilities",
            "routing_role",
            "profile",
            "model_tier",
            "output_contract",
            "max_turns",
            "constraints",
        }
        if profiles.get(agent.get("profile"), {}).get("write"):
            allowed_fields.add("write_scope")
        exact_keys(agent, allowed_fields, f"agent {agent.get('name', '<unnamed>')}")
        missing = set(agent["capabilities"]) - known_capabilities
        if missing:
            raise ValueError(f"{agent['name']} references unknown capabilities: {sorted(missing)}")
        for field in ("when_to_use", "avoid_when", "routing_role"):
            if not agent.get(field):
                raise ValueError(f"{agent['name']} must declare {field}")
        if agent["profile"] not in profiles:
            raise ValueError(f"{agent['name']} references unknown profile {agent['profile']}")
        if agent["output_contract"] not in outputs or agent["output_contract"] == "common":
            raise ValueError(f"{agent['name']} references unknown output contract {agent['output_contract']}")
        if agent["routing_role"] not in policy["routing"]:
            raise ValueError(f"{agent['name']} references unknown routing role {agent['routing_role']}")
        expected_tier = policy["routing"][agent["routing_role"]]
        if agent["model_tier"] != expected_tier:
            raise ValueError(f"{agent['name']} must use routed tier {expected_tier}")
        if agent["model_tier"] not in codex["models"] or agent["model_tier"] not in claude["models"]:
            raise ValueError(f"{agent['name']} references an unbound model tier")
        if profiles[agent["profile"]]["write"] and "write_scope" not in agent:
            raise ValueError(f"writable agent {agent['name']} must declare write_scope")


def validate_neutral_core(ai: Path) -> None:
    provider_terms = re.compile(r"\b(gpt-5|codex|claude|opus|sonnet|haiku)\b", re.IGNORECASE)
    paths = [ai / "policy.yaml", ai / "capabilities/map.yaml", ai / "capabilities/profiles.yaml"]
    paths.extend(sorted((ai / "agents").glob("*.yaml")))
    for path in paths:
        if provider_terms.search(path.read_text(encoding="utf-8")):
            raise ValueError(f"provider-specific term leaked into neutral source: {path}")


def build_outputs(root: Path) -> dict[Path, str]:
    ai = root / ".ai"
    project = load_yaml(ai / "project.yaml")
    exact_keys(project, {"version", "project", "context", "spec", "budgets"}, "project spec")
    exact_keys(project["project"], {"name", "summary"}, "project identity")
    exact_keys(project["context"], {"always", "conditional"}, "project context")
    exact_keys(project["context"]["conditional"], {"architecture", "conventions", "decisions", "active"}, "conditional context")
    exact_keys(project["spec"], {"policy", "contract_evals"}, "compiled spec paths")
    exact_keys(
        project["budgets"],
        {"always_loaded_tokens", "adapter_tokens", "skill_descriptions_tokens", "skill_entry_tokens", "agent_contract_tokens"},
        "token budgets",
    )
    policy = load_yaml(root / project["spec"]["policy"])
    scenarios = load_yaml(root / project["spec"]["contract_evals"])
    capability_map = load_yaml(ai / "capabilities/map.yaml")
    profiles = load_yaml(ai / "capabilities/profiles.yaml")["profiles"]
    codex = load_yaml(ai / "capabilities/runtimes/codex.yaml")
    claude = load_yaml(ai / "capabilities/runtimes/claude.yaml")
    agents = [load_yaml(path) for path in sorted((ai / "agents").glob("*.yaml"))]

    validate_policy(policy, capability_map)
    validate_scenarios(policy, capability_map, scenarios)
    validate_runtime_profiles(profiles, codex, claude)
    validate_agents(agents, capability_map, profiles, policy, codex, claude)
    validate_neutral_core(ai)
    known_capabilities = set(capability_map["capabilities"])

    generated: dict[Path, str] = {
        ai / "instructions.md": render_instructions(policy, project),
        ai / "methodology.md": render_methodology(policy),
        ai / "capabilities/map.md": render_capability_map(capability_map),
        root / "AGENTS.md": render_adapter("codex", codex),
        root / "CLAUDE.md": render_adapter("claude", claude),
        root / "CODEX.md": f"# Codex Adapter\n\n<!-- {GENERATED_MARKER} -->\n\nCodex auto-loads `AGENTS.md`; use it as the runtime entry point.\n",
        root / ".codex/config.toml": render_codex_config(codex),
    }
    for agent in agents:
        neutral_profile = profiles[agent["profile"]]
        filename = agent["name"].replace("_", "-")
        generated[root / ".codex/agents" / f"{filename}.toml"] = render_codex_agent(
            agent, codex, capability_map, policy, neutral_profile
        )
        generated[root / ".claude/agents" / f"{filename}.md"] = render_claude_agent(
            agent, claude, capability_map, policy, neutral_profile
        )

    budgets = project["budgets"]
    for path, text in generated.items():
        if path.name in {"AGENTS.md", "CLAUDE.md", "CODEX.md"} and estimate_tokens(text) > budgets["adapter_tokens"]:
            raise ValueError(f"{path} exceeds adapter token budget")
        if "/agents/" in path.as_posix() and estimate_tokens(text) > budgets["agent_contract_tokens"]:
            raise ValueError(f"{path} exceeds agent contract token budget")

    shared_total = 0
    for relative in project["context"]["always"]:
        path = root / relative
        text = generated.get(path, path.read_text(encoding="utf-8"))
        shared_total += estimate_tokens(text)
    runtime_total = shared_total + max(
        estimate_tokens(generated[root / "AGENTS.md"]),
        estimate_tokens(generated[root / "CLAUDE.md"]),
    )
    if runtime_total > budgets["always_loaded_tokens"]:
        raise ValueError(
            f"always-loaded estimate {runtime_total} exceeds {budgets['always_loaded_tokens']} tokens"
        )

    description_total = 0
    for skill_dir in sorted((ai / "skills").iterdir()):
        if not skill_dir.is_dir():
            continue
        skill_path = skill_dir / "SKILL.md"
        manifest_path = skill_dir / "manifest.yaml"
        if not skill_path.exists() or not manifest_path.exists():
            raise ValueError(f"{skill_dir} must contain SKILL.md and manifest.yaml")
        content = skill_path.read_text(encoding="utf-8")
        match = re.match(r"^---\n(.*?)\n---\n", content, re.DOTALL)
        if not match:
            raise ValueError(f"{skill_path} has invalid frontmatter")
        frontmatter = yaml.safe_load(match.group(1))
        manifest = load_yaml(manifest_path)
        if frontmatter.get("name") != manifest.get("name") or manifest.get("name") != skill_dir.name:
            raise ValueError(f"skill name mismatch in {skill_dir}")
        description_total += estimate_tokens(str(frontmatter.get("description", "")))
        entry_budget = manifest.get("budgets", {}).get("entry_tokens", budgets["skill_entry_tokens"])
        entry_tokens = estimate_tokens(content)
        if entry_tokens > entry_budget:
            raise ValueError(f"{skill_path} estimate {entry_tokens} exceeds {entry_budget} tokens")
        missing_capabilities = set(manifest.get("requires_capabilities", [])) - known_capabilities
        if missing_capabilities:
            raise ValueError(f"{manifest_path} references unknown capabilities: {sorted(missing_capabilities)}")
        for reference in manifest.get("references", []):
            if not (skill_dir / reference).exists():
                raise ValueError(f"{manifest_path} references missing path {reference}")
    if description_total > budgets["skill_descriptions_tokens"]:
        raise ValueError(
            f"skill description estimate {description_total} exceeds {budgets['skill_descriptions_tokens']} tokens"
        )
    return generated


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    generated = build_outputs(root)
    stale: list[Path] = []
    for path, text in generated.items():
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != text:
                stale.append(path)
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        print(f"generated {path.relative_to(root)}")
    if not args.check:
        for directory, suffix in ((root / ".codex/agents", ".toml"), (root / ".claude/agents", ".md")):
            for path in directory.glob(f"*{suffix}"):
                if path not in generated and GENERATED_MARKER in path.read_text(encoding="utf-8"):
                    path.unlink()
                    print(f"removed stale generated file {path.relative_to(root)}")
    if stale:
        for path in stale:
            print(f"stale generated file: {path.relative_to(root)}", file=sys.stderr)
        return 1
    if args.check:
        print(f"agent spec valid; {len(generated)} generated files are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
