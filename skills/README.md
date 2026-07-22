# Skill Archives

Deterministic `.skill` archives are built from the one default skill under `template/.ai/skills/` and the opt-in skills under `skill-catalog/`.

The manifest `package` allowlist is authoritative. Packaging fixes timestamps and file order; `tests/test-skills.sh` rejects missing, stale, or drifted archives.

Run the packager from the repository root:

```bash
export PYTHONPATH="$PWD/template/.ai/catalog/skill-authoring"
python -m scripts.package_skill template/.ai/skills/agent-context skills
for skill in template/.ai/catalog/*/; do
  [ -f "$skill/SKILL.md" ] || continue
  python -m scripts.package_skill "$skill" skills
done
```

Then run `nix develop path:. -c bash tests/test-skills.sh` from the repository root.
