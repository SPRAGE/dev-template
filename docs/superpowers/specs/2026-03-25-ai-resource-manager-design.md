# AI Resource Manager — Design Spec

## Overview

Add "Quinn," an AI Resource Manager, to the virtual-tech-organization skill's leadership layer. Quinn proactively assesses talent gaps and collaboratively hires domain expert personas on-the-fly, enabling the org to adapt its expertise to any project's unique domain, regulatory, and technical requirements.

**Approach:** Standalone skill (`ai-resource-manager`) that coordinates with VTO via `project-state.json` as shared state. VTO does not invoke Quinn directly — instead, VTO recommends that the user invoke `/ai-resource-manager` at key lifecycle points (handoff protocol).

## Persona & Role Definition

**Name:** Quinn, AI Resource Manager
(Note: "Morgan" was considered but is already used by the Technical Writer in VTO's engineering team.)

**Layer:** Leadership (user-facing conversational persona), peer to CEO (Alex), CTO (Jordan), and Domain Expert (Riley).

**Personality:**
- Analytical and methodical — assesses needs before acting
- Collaborative — always involves the user in defining expert profiles
- Proactive but not pushy — surfaces recommendations, doesn't force hires
- Quality-focused — would rather have 3 great experts than 6 mediocre ones

**Authority scope:**
- Can *recommend* hires — user approves
- Can *bench/reactivate* experts — notifies user
- Can *propose promotions* to permanent skills — user approves
- Cannot override CEO product decisions or CTO technical decisions
- Cannot modify existing VTO roles (Alex, Jordan, Riley, or the ruflo engineering team)

**Speaking style example:**
> "Looking at this fintech project, we're going to need someone who lives and breathes PCI-DSS compliance. I have a profile in mind — want me to walk you through the candidate?"

## Talent Lifecycle

Quinn manages experts through five phases:

### 1. Assess — Identify talent gaps

- **Proactive (Stage 0-1):** After the product brief and architecture doc are produced, Quinn analyzes the domain, regulatory landscape, tech stack, and archetype to recommend an initial expert roster.
- **Reactive (any stage):** Team members flag gaps ("we need help with X"), or Quinn detects struggles in ongoing work (e.g., CTO hitting repeated blockers in a domain area).
- **Inputs:** `project-state.json`, product brief, architecture doc, tech stack, team feedback, domain signals.

### 2. Propose — Present a candidate profile

Quinn drafts a one-paragraph role description:

> "**Dr. Yara Okonkwo — Payment Systems Architect.** Specializes in PCI-DSS compliance, payment gateway integrations, tokenization patterns, and fraud detection pipelines. Would advise on transaction flow design and audit requirements."

User approves or refines before moving forward.

### 3. Define — Collaborative interview

Quinn asks 3-5 targeted questions to shape the expert's knowledge and focus:

- What specific problems should this expert solve?
- What domain knowledge is non-negotiable vs nice-to-have?
- Any specific frameworks, standards, or methodologies they should know?
- How should they interact with the existing team?

### 4. Create — Write the expert skill

Quinn generates a lightweight SKILL.md placed at `project/experts/<name>/SKILL.md`. See "Expert Skill Structure" section below.

### 5. Manage — Bench rotation and promotion

- **Bench:** When an expert isn't needed for the current stage, Quinn moves them to inactive. They can be reactivated instantly.
- **Promote:** After a successful engagement, Quinn can package the expert as a `.skill` file for reuse in future projects using the skill-creator's packaging infrastructure.

## Integration with Virtual-Tech-Org

### Updated org chart

| Role | Name | Layer |
|------|------|-------|
| CEO | Alex | Leadership (user-facing) |
| CTO | Jordan | Leadership (user-facing) |
| Domain Expert | Riley | Leadership (user-facing) |
| Resource Manager | Quinn | Leadership (user-facing) |

### Handoff protocol

VTO does not invoke Quinn via `Skill()` — Claude Code's Skill tool does not support nested multi-turn interactive invocations within an already-active skill. Instead, VTO uses a **handoff protocol**: at defined trigger points, the CTO or CEO recommends that the user invoke `/ai-resource-manager` to run a talent assessment. Quinn then reads `project-state.json` for context and writes results back to it.

### Trigger points in VTO lifecycle

| Stage | Quinn's Role | CTO/CEO Handoff |
|-------|-------------|-----------------|
| 0: Discovery | Talent assessment based on product brief | After CEO presents the product brief and user approves the gate review, CTO says: "Before we move to architecture, I'd recommend bringing in Quinn to assess what specialist expertise we'll need. Run `/ai-resource-manager` to start a talent assessment." |
| 1: Architecture | Analyzes tech stack + domain, presents hiring recommendations | After architecture doc is finalized, CTO says: "Now that we've locked the tech stack, let's have Quinn review whether we need any specialists. Run `/ai-resource-manager`." |
| 2: Prototype | On standby — responds to team feedback if gaps emerge | Reactive only — CTO or user invokes when gaps surface |
| 3: MVP | Monitors for knowledge gaps as complexity increases | Reactive — CTO flags if agents struggle with domain-specific tasks |
| 4: Production | Assesses need for security/compliance/performance specialists | CTO proactively recommends: "Before production hardening, let's check with Quinn on specialist needs." |
| Gate reviews | Reports on expert utilization — who's active, benched, recommended | Quinn's roster summary is included in project-state.json, which the CTO reads during gate reviews |

### Relationship between Riley and hired experts

Riley remains active as the **generalist domain lead** throughout the project. Hired experts are narrow specialists that augment Riley's knowledge:

- Riley provides broad domain context (industry workflows, regulatory landscape, terminology)
- Hired experts provide deep, specific expertise (e.g., "PCI-DSS section 3.4 tokenization requirements")
- Riley integrates expert advice into domain recommendations to the CEO
- Experts do not replace Riley — they report to Riley on domain matters and to the CTO on technical matters
- At gate reviews, Riley summarizes domain status including expert contributions

### project-state.json extension

```json
{
  "talent_roster": [
    {
      "name": "Dr. Yara Okonkwo",
      "role": "Payment Systems Architect",
      "status": "active|benched|promoted|released",
      "hired_stage": 1,
      "skill_path": "project/experts/yara-okonkwo/SKILL.md",
      "promoted_to_skill": null
    }
  ],
  "talent_cap": 5,
  "talent_assessments": [
    {
      "stage": 0,
      "gaps_identified": ["PCI-DSS compliance", "payment gateway integration"],
      "recommendations": ["Payment Systems Architect"]
    }
  ]
}
```

**`project-state.json` is the single source of truth** for all talent state. No separate roster file.

### Fallback when ai-resource-manager is not installed

If the `ai-resource-manager` skill is absent, VTO degrades gracefully:
- CTO skips talent assessment handoff recommendations
- Riley absorbs the generalist domain expert role (current behavior)
- No errors or broken references — VTO checks for the skill's existence before recommending it

## Expert Skill Structure

### Directory layout

Experts live outside `.claude/skills/` to avoid polluting Claude Code's auto-discovery:

```
project/experts/
├── yara-okonkwo/
│   └── SKILL.md
└── kai-nakamura/
    └── SKILL.md
```

Quinn reads expert SKILL.md files explicitly when activating them, using the Read tool. Auto-discovery only applies to promoted experts that have been moved to `.claude/skills/`.

### Expert SKILL.md template

```yaml
---
name: <slug>
description: >
  <Full name> — <Title>. <One-line specialization summary>.
  Invoke when discussing <trigger topics>.
---

# <Full Name> — <Title>

## Metadata
- **Hired by:** Quinn (AI Resource Manager)
- **Project:** <project-name>
- **Hired at stage:** <N>
- **Status:** active

## Identity
<Name, title, personality, speaking style>

## Domain Expertise
<Specific knowledge areas, standards, frameworks, methodologies>

## Interaction Model
Advisory role. Reports to Riley on domain matters, to CTO (Jordan) on technical matters.
Does not have decision-making authority unless explicitly delegated by CEO or CTO.
<How they relate to Alex, Jordan, Riley, and other experts>

## Focus Areas
<What they actively contribute to in this project>

## Boundaries
<What they explicitly don't opine on>
```

Note: Only standard frontmatter fields (`name`, `description`) are used. Project-specific metadata (hired_by, project, status) lives in the Metadata body section to stay compatible with the skill-creator's validation.

### Quick hire vs promoted skill

| Aspect | Quick hire | Promoted |
|--------|-----------|----------|
| Location | `project/experts/` | `.claude/skills/` (top-level) |
| Structure | Single SKILL.md | SKILL.md + `references/` with domain docs |
| Scope | Project-bound | Reusable across projects |
| Discovery | Read explicitly by Quinn | Auto-discovered by Claude Code |
| Packaging | None | `.skill` archive via skill-creator |

### Promotion process

1. Quinn proposes promotion with rationale ("Yara was critical in 3 stages, this expertise will recur")
2. User approves
3. Quinn enriches the SKILL.md — adds `references/` directory with domain documentation, generalizes project-specific language, refines the trigger description
4. Updates `project-state.json`: sets the expert's `status` to `"promoted"` and `promoted_to_skill` to the new `.claude/skills/<name>/` path
5. Invokes skill-creator's packaging infrastructure (`.claude/skills/skill-creator/scripts/package_skill.py`) to create a distributable `.skill` archive
6. Moves from `project/experts/` to `.claude/skills/` for auto-discovery

## AI Resource Manager Skill Structure

### Directory layout

```
ai-resource-manager/
├── SKILL.md                           # Main skill definition
└── references/
    ├── expert-template.md             # Template for generating expert SKILL.md files
    ├── assessment-criteria.md         # Framework for evaluating talent gaps
    └── promotion-checklist.md         # Quality bar for promoting to permanent
```

No scripts directory — Quinn manipulates `project-state.json` directly using Read/Write/Edit tools, consistent with how `init_project.py` already manages project state.

### SKILL.md frontmatter

```yaml
---
name: ai-resource-manager
description: >
  Quinn, the AI Resource Manager. Assesses talent needs, collaboratively
  hires domain expert personas, and manages the expert bench. Invoke when
  you need specialized expertise, want to assess talent gaps, or manage
  hired experts. Triggers: "hire an expert", "we need a specialist",
  "talent assessment", "who's on the team", "bench/activate expert".
tools: Read, Write, Edit, Glob, Grep, Bash
---
```

### SKILL.md sections

1. **Persona definition** — Quinn's identity, speaking style, authority scope
2. **Proactive assessment protocol** — how Quinn analyzes project state to recommend hires (reads product brief, architecture doc, tech stack, domain signals)
3. **Hiring workflow** — the 5-phase lifecycle (Assess, Propose, Define, Create, Manage)
4. **Expert template** — the SKILL.md template Quinn uses when writing expert skills (references `references/expert-template.md`)
5. **Bench management** — rules for active expert cap, benching criteria, reactivation
6. **Talent cap enforcement** — `talent_cap` in project-state.json defines the maximum number of *active* experts (default 5, excludes benched/promoted/released). When the cap is reached, Quinn tells the user and asks them to bench an existing expert before hiring a new one. The user can explicitly raise the cap if needed.
7. **Promotion pipeline** — criteria for promoting project-scoped experts to permanent skills, enrichment steps, packaging via skill-creator
8. **Integration protocol** — how Quinn reads/writes `project-state.json`, how VTO hands off to Quinn at lifecycle points

## Changes to Existing Files

### VTO updates required (implementation needed)

1. **`org-roles.md`** — Add Quinn to the leadership table with authority scope and interaction model
2. **`workflow-stages.md`** — Add Quinn's handoff recommendations at Stage 0, 1, and 4 trigger points
3. **`SKILL.md` (VTO)** — Add handoff protocol: CTO/CEO recommends `/ai-resource-manager` at trigger points; add fallback check (if skill not installed, skip recommendation)
4. **`init_project.py`** — Extend `project-state.json` schema with `talent_roster`, `talent_cap`, and `talent_assessments` fields; add Quinn to leadership personas

### Template updates (implementation needed)

5. **`template/.claude/skills/`** — Add `ai-resource-manager/` directory with SKILL.md and references/
6. **`project/experts/`** — Created at runtime by Quinn when first expert is hired (not in template)
7. **`flake.nix`** — No changes needed (sync-skills already syncs all directories under `template/.claude/skills/`)
