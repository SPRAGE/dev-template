#!/usr/bin/env python3
"""Offline contract tests for the behavioral evaluation harness."""

from __future__ import annotations

import copy
import importlib.util
import sys
import unittest
from pathlib import Path

import yaml


sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[1]
HARNESS_PATH = REPO / "tools/eval_harness.py"
BENCHMARK_PATH = REPO / "evals/behavioral/benchmark.yaml"


def load_harness():
    spec = importlib.util.spec_from_file_location("eval_harness", HARNESS_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {HARNESS_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


harness = load_harness()
BENCHMARK = yaml.safe_load(BENCHMARK_PATH.read_text(encoding="utf-8"))


def make_trial(task: dict, condition: str) -> dict:
    candidate = condition == "candidate"
    return {
        "id": f"{task['id']}-{condition}-1",
        "pair_id": f"{task['id']}-1",
        "task": task["id"],
        "condition": condition,
        "repetition": 1,
        "frozen": {
            "repository_revision": "0123456789abcdef",
            "runtime": "offline-fixture",
            "model": "fixed-model",
            "settings_digest": "same-settings",
            "tools": ["read", "write", "test"],
        },
        "outcome": {
            "success": candidate,
            "regressions": 0 if candidate else 1,
            "safety_violations": 0,
            "unnecessary_actions": 1 if candidate else 3,
            "clarifications": 0 if candidate else 1,
            "tool_calls": 8 if candidate else 10,
            "input_tokens": 900 if candidate else 1000,
            "output_tokens": 300 if candidate else 400,
            "latency_ms": 1800 if candidate else 2200,
            "external_cost_usd": 0,
        },
        "checks": {check: candidate for check in task["deterministic_checks"]},
        "grade": {
            "blinded": True,
            "score": 82 if candidate else 58,
            "evidence": ["Synthetic fixture evidence; not a model result."],
            "uncertainty": "low",
        },
    }


def trial_document() -> dict:
    return {
        "version": 1,
        "benchmark_id": BENCHMARK["id"],
        "trials": [
            make_trial(task, condition)
            for task in BENCHMARK["tasks"]
            for condition in ("baseline", "candidate")
        ],
    }


class EvaluationHarnessTests(unittest.TestCase):
    def test_benchmark_and_paired_comparison(self) -> None:
        result = harness.compare(BENCHMARK, trial_document())
        self.assertEqual(result["overall"]["pairs"], len(BENCHMARK["tasks"]))
        self.assertEqual(result["overall"]["success_rate_pct"]["delta_pp"], 100)
        self.assertEqual(result["overall"]["mean_candidate_minus_baseline"]["total_tokens"], -200)
        self.assertEqual(result["overall"]["pair_outcomes"]["wins"], len(BENCHMARK["tasks"]))
        self.assertIn("Offline aggregation only", result["claim_boundary"])

    def test_changed_frozen_settings_are_rejected(self) -> None:
        document = trial_document()
        document["trials"][1]["frozen"]["model"] = "different-model"
        with self.assertRaisesRegex(harness.EvaluationError, "changed frozen runtime settings"):
            harness.compare(BENCHMARK, document)

    def test_mixed_settings_across_pairs_are_rejected(self) -> None:
        document = trial_document()
        document["trials"][2]["frozen"]["model"] = "different-model"
        document["trials"][3]["frozen"]["model"] = "different-model"
        with self.assertRaisesRegex(harness.EvaluationError, "mixes frozen runtime settings"):
            harness.compare(BENCHMARK, document)

    def test_unblinded_grade_is_rejected(self) -> None:
        document = trial_document()
        document["trials"][0]["grade"]["blinded"] = False
        with self.assertRaisesRegex(harness.EvaluationError, "was not blinded"):
            harness.compare(BENCHMARK, document)

    def test_missing_pair_condition_is_rejected(self) -> None:
        document = trial_document()
        document["trials"] = document["trials"][:-1]
        with self.assertRaisesRegex(harness.EvaluationError, "must contain one baseline and one candidate"):
            harness.compare(BENCHMARK, document)

    def test_omitted_task_is_rejected(self) -> None:
        document = trial_document()
        omitted = BENCHMARK["tasks"][-1]["id"]
        document["trials"] = [trial for trial in document["trials"] if trial["task"] != omitted]
        with self.assertRaisesRegex(harness.EvaluationError, "omits benchmark tasks"):
            harness.compare(BENCHMARK, document)

    def test_boolean_count_is_rejected(self) -> None:
        document = trial_document()
        document["trials"][0]["outcome"]["tool_calls"] = True
        with self.assertRaisesRegex(harness.EvaluationError, "non-negative integers"):
            harness.compare(BENCHMARK, document)

    def test_unbalanced_repetitions_are_rejected(self) -> None:
        document = trial_document()
        first_task = BENCHMARK["tasks"][0]
        for condition in ("baseline", "candidate"):
            trial = make_trial(first_task, condition)
            trial["id"] = f"{first_task['id']}-{condition}-2"
            trial["pair_id"] = f"{first_task['id']}-2"
            trial["repetition"] = 2
            document["trials"].append(trial)
        with self.assertRaisesRegex(harness.EvaluationError, "same repetition set"):
            harness.compare(BENCHMARK, document)

    def test_pair_ranking_prioritizes_safety(self) -> None:
        document = trial_document()
        baseline, candidate = document["trials"][:2]
        baseline["outcome"]["success"] = True
        baseline["checks"] = {check: True for check in baseline["checks"]}
        baseline["outcome"]["regressions"] = 0
        baseline["grade"]["score"] = 50
        candidate["outcome"]["safety_violations"] = 1
        candidate["grade"]["score"] = 100
        result = harness.compare(BENCHMARK, document)
        self.assertEqual(result["by_task"]["direct-bug"]["pair_outcomes"]["losses"], 1)

    def test_success_with_failed_check_is_rejected(self) -> None:
        document = trial_document()
        candidate = document["trials"][1]
        first_check = next(iter(candidate["checks"]))
        candidate["checks"][first_check] = False
        with self.assertRaisesRegex(harness.EvaluationError, "cannot succeed with a failed deterministic check"):
            harness.compare(BENCHMARK, document)

    def test_input_is_not_mutated(self) -> None:
        document = trial_document()
        original = copy.deepcopy(document)
        harness.compare(BENCHMARK, document)
        self.assertEqual(document, original)


if __name__ == "__main__":
    unittest.main()
