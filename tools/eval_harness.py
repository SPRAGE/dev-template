#!/usr/bin/env python3
"""Validate and compare offline paired agent-evaluation records."""

from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
from pathlib import Path

import yaml


CONDITIONS = {"baseline", "candidate"}
OUTCOME_FIELDS = {
    "success",
    "regressions",
    "safety_violations",
    "unnecessary_actions",
    "clarifications",
    "tool_calls",
    "input_tokens",
    "output_tokens",
    "latency_ms",
    "external_cost_usd",
}
COUNT_FIELDS = OUTCOME_FIELDS - {"success", "external_cost_usd"}
FROZEN_FIELDS = {"repository_revision", "runtime", "model", "settings_digest", "tools"}
GRADE_FIELDS = {"blinded", "score", "evidence", "uncertainty"}
TASK_FIELDS = {"id", "class", "prompt", "expected", "prohibited", "deterministic_checks", "rubric"}
TRIAL_FIELDS = {"id", "pair_id", "task", "condition", "repetition", "frozen", "outcome", "checks", "grade"}


class EvaluationError(ValueError):
    pass


def load_yaml(path: Path) -> dict:
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, yaml.YAMLError) as error:
        raise EvaluationError(f"cannot read {path}: {error}") from error
    if not isinstance(data, dict):
        raise EvaluationError(f"{path} must contain a YAML mapping")
    return data


def exact_keys(data: dict, expected: set[str], label: str) -> None:
    if not isinstance(data, dict) or set(data) != expected:
        actual = set(data) if isinstance(data, dict) else set()
        raise EvaluationError(
            f"{label} keys differ: "
            f"missing={sorted(expected - actual, key=str)}, "
            f"unused={sorted(actual - expected, key=str)}"
        )


def nonempty_strings(values: object) -> bool:
    return isinstance(values, list) and bool(values) and all(isinstance(value, str) and value.strip() for value in values)


def validate_benchmark(benchmark: dict) -> dict[str, dict]:
    exact_keys(benchmark, {"version", "id", "decision", "conditions", "metrics", "tasks"}, "benchmark")
    if benchmark["version"] != 1 or not isinstance(benchmark["id"], str) or not benchmark["id"].strip():
        raise EvaluationError("benchmark version or id is invalid")
    if not isinstance(benchmark["decision"], str) or not benchmark["decision"].strip():
        raise EvaluationError("benchmark decision must be a non-empty string")
    if (
        not isinstance(benchmark["conditions"], list)
        or not all(isinstance(condition, str) for condition in benchmark["conditions"])
        or set(benchmark["conditions"]) != CONDITIONS
        or len(benchmark["conditions"]) != len(CONDITIONS)
    ):
        raise EvaluationError("benchmark conditions must be baseline and candidate")
    if (
        not isinstance(benchmark["metrics"], list)
        or not all(isinstance(metric, str) for metric in benchmark["metrics"])
        or set(benchmark["metrics"]) != OUTCOME_FIELDS
        or len(benchmark["metrics"]) != len(OUTCOME_FIELDS)
    ):
        raise EvaluationError("benchmark metrics do not match the trial outcome contract")
    if not isinstance(benchmark["tasks"], list) or not benchmark["tasks"]:
        raise EvaluationError("benchmark must contain tasks")
    tasks: dict[str, dict] = {}
    for task in benchmark["tasks"]:
        exact_keys(task, TASK_FIELDS, "benchmark task")
        task_id = task["id"]
        if not isinstance(task_id, str) or not task_id or task_id in tasks:
            raise EvaluationError(f"invalid or duplicate benchmark task id: {task_id!r}")
        if not isinstance(task["class"], str) or task["class"] not in {
            "normal",
            "hard",
            "near-miss",
            "adversarial",
        }:
            raise EvaluationError(f"task {task_id} has an invalid class")
        if not isinstance(task["prompt"], str) or not task["prompt"].strip():
            raise EvaluationError(f"task {task_id} has no prompt")
        for field in ("expected", "prohibited", "deterministic_checks"):
            if not nonempty_strings(task[field]) or len(task[field]) != len(set(task[field])):
                raise EvaluationError(f"task {task_id} has invalid {field}")
        rubric = task["rubric"]
        exact_keys(rubric, {"correctness", "safety", "efficiency", "grounding"}, f"task {task_id} rubric")
        if not all(type(weight) is int and weight >= 0 for weight in rubric.values()) or sum(rubric.values()) != 100:
            raise EvaluationError(f"task {task_id} rubric weights must be non-negative and sum to 100")
        tasks[task_id] = task
    return tasks


def validate_trial(trial: dict, tasks: dict[str, dict]) -> None:
    exact_keys(trial, TRIAL_FIELDS, "trial")
    for field in ("id", "pair_id"):
        if not isinstance(trial[field], str) or not trial[field]:
            raise EvaluationError(f"trial {field} must be a non-empty string")
    if not isinstance(trial["task"], str) or trial["task"] not in tasks:
        raise EvaluationError(f"trial references unknown task: {trial['task']}")
    if not isinstance(trial["condition"], str) or trial["condition"] not in CONDITIONS:
        raise EvaluationError(f"trial {trial['id']} has an invalid condition")
    if type(trial["repetition"]) is not int or trial["repetition"] < 1:
        raise EvaluationError(f"trial {trial['id']} repetition must be positive")

    frozen = trial["frozen"]
    exact_keys(frozen, FROZEN_FIELDS, f"trial {trial['id']} frozen settings")
    for field in FROZEN_FIELDS - {"tools"}:
        if not isinstance(frozen[field], str) or not frozen[field]:
            raise EvaluationError(f"trial {trial['id']} frozen {field} is invalid")
    if (
        not isinstance(frozen["tools"], list)
        or not all(isinstance(tool, str) and tool.strip() for tool in frozen["tools"])
        or len(frozen["tools"]) != len(set(frozen["tools"]))
    ):
        raise EvaluationError(f"trial {trial['id']} frozen tools are invalid")

    outcome = trial["outcome"]
    exact_keys(outcome, OUTCOME_FIELDS, f"trial {trial['id']} outcome")
    if not isinstance(outcome["success"], bool):
        raise EvaluationError(f"trial {trial['id']} success must be boolean")
    if not all(type(outcome[field]) is int and outcome[field] >= 0 for field in COUNT_FIELDS):
        raise EvaluationError(f"trial {trial['id']} count and latency metrics must be non-negative integers")
    cost = outcome["external_cost_usd"]
    if (
        isinstance(cost, bool)
        or not isinstance(cost, (int, float))
        or not math.isfinite(cost)
        or cost < 0
    ):
        raise EvaluationError(f"trial {trial['id']} external cost is invalid")

    checks = trial["checks"]
    expected_checks = set(tasks[trial["task"]]["deterministic_checks"])
    if not isinstance(checks, dict) or set(checks) != expected_checks or not all(isinstance(value, bool) for value in checks.values()):
        raise EvaluationError(f"trial {trial['id']} deterministic checks do not match its task")
    if outcome["success"] and not all(checks.values()):
        raise EvaluationError(f"trial {trial['id']} cannot succeed with a failed deterministic check")

    grade = trial["grade"]
    exact_keys(grade, GRADE_FIELDS, f"trial {trial['id']} grade")
    if grade["blinded"] is not True:
        raise EvaluationError(f"trial {trial['id']} grade was not blinded")
    score = grade["score"]
    if (
        isinstance(score, bool)
        or not isinstance(score, (int, float))
        or not math.isfinite(score)
        or not 0 <= score <= 100
    ):
        raise EvaluationError(f"trial {trial['id']} grade score must be from 0 to 100")
    if not nonempty_strings(grade["evidence"]):
        raise EvaluationError(f"trial {trial['id']} grade needs evidence")
    if not isinstance(grade["uncertainty"], str) or grade["uncertainty"] not in {"low", "medium", "high"}:
        raise EvaluationError(f"trial {trial['id']} grade uncertainty is invalid")


def validate_trials(document: dict, benchmark: dict, tasks: dict[str, dict]) -> list[tuple[dict, dict]]:
    exact_keys(document, {"version", "benchmark_id", "trials"}, "trial document")
    if document["version"] != 1 or document["benchmark_id"] != benchmark["id"]:
        raise EvaluationError("trial document version or benchmark id does not match")
    if not isinstance(document["trials"], list) or not document["trials"]:
        raise EvaluationError("trial document must contain trials")
    ids: set[str] = set()
    grouped: dict[str, dict[str, dict]] = {}
    for trial in document["trials"]:
        validate_trial(trial, tasks)
        if trial["id"] in ids:
            raise EvaluationError(f"duplicate trial id: {trial['id']}")
        ids.add(trial["id"])
        pair = grouped.setdefault(trial["pair_id"], {})
        if trial["condition"] in pair:
            raise EvaluationError(f"pair {trial['pair_id']} duplicates condition {trial['condition']}")
        pair[trial["condition"]] = trial

    pairs: list[tuple[dict, dict]] = []
    task_repetitions: set[tuple[str, int]] = set()
    experiment_frozen: dict | None = None
    for pair_id, pair in sorted(grouped.items()):
        if set(pair) != CONDITIONS:
            raise EvaluationError(f"pair {pair_id} must contain one baseline and one candidate")
        baseline, candidate = pair["baseline"], pair["candidate"]
        if baseline["task"] != candidate["task"] or baseline["repetition"] != candidate["repetition"]:
            raise EvaluationError(f"pair {pair_id} task or repetition differs")
        if baseline["frozen"] != candidate["frozen"]:
            raise EvaluationError(f"pair {pair_id} changed frozen runtime settings")
        if experiment_frozen is None:
            experiment_frozen = baseline["frozen"]
        elif baseline["frozen"] != experiment_frozen:
            raise EvaluationError("trial document mixes frozen runtime settings across pairs")
        task_repetition = (baseline["task"], baseline["repetition"])
        if task_repetition in task_repetitions:
            raise EvaluationError(
                f"task {baseline['task']} repeats repetition {baseline['repetition']} under multiple pair ids"
            )
        task_repetitions.add(task_repetition)
        pairs.append((baseline, candidate))
    missing_tasks = set(tasks) - {baseline["task"] for baseline, _ in pairs}
    if missing_tasks:
        raise EvaluationError(f"trial document omits benchmark tasks: {sorted(missing_tasks)}")
    repetitions_by_task = {
        task_id: {baseline["repetition"] for baseline, _ in pairs if baseline["task"] == task_id}
        for task_id in tasks
    }
    if len({frozenset(repetitions) for repetitions in repetitions_by_task.values()}) != 1:
        raise EvaluationError("benchmark tasks must use the same repetition set")
    return pairs


def mean(values: list[float]) -> float:
    return statistics.fmean(values) if values else 0.0


def summarize_pairs(pairs: list[tuple[dict, dict]]) -> dict:
    success_baseline = mean([float(pair[0]["outcome"]["success"]) for pair in pairs]) * 100
    success_candidate = mean([float(pair[1]["outcome"]["success"]) for pair in pairs]) * 100
    deltas: dict[str, float] = {}
    for field in sorted(OUTCOME_FIELDS - {"success"}):
        deltas[field] = round(
            mean([float(candidate["outcome"][field]) - float(baseline["outcome"][field]) for baseline, candidate in pairs]),
            3,
        )
    deltas["total_tokens"] = round(
        mean(
            [
                float(candidate["outcome"]["input_tokens"] + candidate["outcome"]["output_tokens"])
                - float(baseline["outcome"]["input_tokens"] + baseline["outcome"]["output_tokens"])
                for baseline, candidate in pairs
            ]
        ),
        3,
    )
    grade_delta = round(
        mean([float(candidate["grade"]["score"]) - float(baseline["grade"]["score"]) for baseline, candidate in pairs]),
        3,
    )
    wins = losses = ties = 0
    for baseline, candidate in pairs:
        baseline_rank = (
            -baseline["outcome"]["safety_violations"],
            baseline["outcome"]["success"],
            -baseline["outcome"]["regressions"],
            baseline["grade"]["score"],
        )
        candidate_rank = (
            -candidate["outcome"]["safety_violations"],
            candidate["outcome"]["success"],
            -candidate["outcome"]["regressions"],
            candidate["grade"]["score"],
        )
        if candidate_rank > baseline_rank:
            wins += 1
        elif candidate_rank < baseline_rank:
            losses += 1
        else:
            ties += 1
    return {
        "pairs": len(pairs),
        "success_rate_pct": {
            "baseline": round(success_baseline, 3),
            "candidate": round(success_candidate, 3),
            "delta_pp": round(success_candidate - success_baseline, 3),
        },
        "mean_candidate_minus_baseline": deltas,
        "mean_blinded_grade_delta": grade_delta,
        "pair_outcomes": {"wins": wins, "losses": losses, "ties": ties},
        "uncertainty": "high" if len(pairs) < 5 else "requires task-level inspection",
    }


def compare(benchmark: dict, document: dict) -> dict:
    tasks = validate_benchmark(benchmark)
    pairs = validate_trials(document, benchmark, tasks)
    by_task = {
        task_id: summarize_pairs([pair for pair in pairs if pair[0]["task"] == task_id])
        for task_id in sorted({pair[0]["task"] for pair in pairs})
    }
    return {
        "benchmark_id": benchmark["id"],
        "decision": benchmark["decision"],
        "overall": summarize_pairs(pairs),
        "by_task": by_task,
        "claim_boundary": "Offline aggregation only; results are evidence only if trials were actually run under the frozen settings.",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "compare"))
    parser.add_argument("--benchmark", type=Path, required=True)
    parser.add_argument("--trials", type=Path)
    args = parser.parse_args()
    try:
        benchmark = load_yaml(args.benchmark)
        tasks = validate_benchmark(benchmark)
        if args.trials is None:
            if args.command == "compare":
                raise EvaluationError("compare requires --trials")
            print(f"valid benchmark: {benchmark['id']} ({len(tasks)} tasks)")
            return 0
        trials = load_yaml(args.trials)
        if args.command == "validate":
            pairs = validate_trials(trials, benchmark, tasks)
            print(f"valid paired trials: {len(pairs)}")
            return 0
        print(json.dumps(compare(benchmark, trials), indent=2, sort_keys=True))
        return 0
    except EvaluationError as error:
        print(f"eval-harness: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
