# Expert Promotion Checklist

Quinn uses this checklist to evaluate whether a project-scoped expert should be promoted to a permanent, reusable skill.

## Promotion Criteria

An expert is a candidate for promotion when:

- [ ] **Engaged across 2+ stages** — the expert contributed meaningfully in multiple stages, not just a one-off consultation
- [ ] **Domain is recurring** — the expertise area is likely to appear in future projects (e.g., payment processing, healthcare compliance, not "legacy system X migration")
- [ ] **Generalizable knowledge** — the expert's knowledge extends beyond this specific project's context
- [ ] **Distinct from Riley** — the expert provides depth that a generalist domain expert cannot reasonably cover
- [ ] **User found value** — the user interacted with or benefited from the expert's contributions

## Promotion Process

### Step 1: Propose to user

Quinn presents the promotion case:
> "Dr. Yara Okonkwo was critical in Stages 1-3 — her PCI-DSS expertise shaped the architecture and caught two compliance issues during MVP. Payment systems expertise will recur in future fintech projects. I'd recommend promoting her to a permanent skill. Approve?"

### Step 2: Enrich the SKILL.md

Transform the quick-hire SKILL.md into a reusable skill:

- [ ] **Generalize project-specific language** — remove references to this specific project, replace with patterns
- [ ] **Add `references/` directory** — include domain documentation, standards references, checklists
- [ ] **Expand domain expertise section** — broaden from project-specific focus to general domain coverage
- [ ] **Refine trigger description** — update the `description` frontmatter field with general trigger phrases
- [ ] **Update Metadata section** — change status to "promoted", add promotion date
- [ ] **Remove project-specific Focus Areas** — replace with general expertise areas

### Step 3: Update project-state.json

```json
{
  "name": "Dr. Yara Okonkwo",
  "status": "promoted",
  "promoted_to_skill": ".claude/skills/yara-okonkwo/"
}
```

### Step 4: Move to skills directory

Move from `project/experts/<name>/` to `.claude/skills/<name>/`.

### Step 5: Package as .skill archive

Use the skill-creator's packaging infrastructure:

```bash
python .claude/skills/skill-creator/scripts/package_skill.py .claude/skills/<name>/ --output .
```

This creates a distributable `<name>.skill` archive that can be installed in other projects.

## Quality Bar

Before packaging, verify:

- [ ] SKILL.md passes validation (`quick_validate.py`)
- [ ] Frontmatter contains only standard fields: `name`, `description`
- [ ] No project-specific paths, names, or configuration remain
- [ ] Domain expertise section covers the breadth of the specialty, not just what this project needed
- [ ] Trigger description in frontmatter is general enough to activate in relevant future projects
- [ ] References directory contains useful domain documentation (not just empty placeholders)
