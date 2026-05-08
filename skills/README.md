# Skill Archives

This folder contains distributable `.skill` archives generated from `template/.ai/skills/`.

- Source of truth: `template/.ai/skills/<skill-name>/`
- Archive output: `skills/<skill-name>.skill`
- Validation: `nix develop -c bash tests/test-skills.sh`

Regenerate an archive after changing a skill source:

```bash
python template/.ai/skills/skill-creator/scripts/package_skill.py template/.ai/skills/<skill-name> skills
```
