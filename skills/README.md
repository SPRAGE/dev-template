# Optional Skill Archives

`agent-context.skill` and `frontend-design.skill` are optional archives. No skill ships in generated projects by default. Source procedures live in `optional/skills/`; validation and packaging stay in `tools/skills/`.

Inside `nix develop path:.`:

```bash
python tools/skills/quick_validate.py optional/skills/agent-context
python tools/skills/package_skill.py optional/skills/agent-context skills
python tools/skills/package_skill.py optional/skills/frontend-design skills
bash tests/test-skills.sh
```

Manifest allowlists control package contents. Tests check exact archives and deterministic rebuilds. Ordinary engineering knowledge needs no skill; keep optional procedures only when real project use justifies them. See [workflow installation](../README.md#optional-workflows).
