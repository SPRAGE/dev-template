# AI Resource Manager — Design Spec

## Overview

Add "Morgan," an AI Resource Manager, to the virtual-tech-organization skill's leadership layer. Morgan proactively assesses talent gaps and collaboratively hires domain expert personas on-the-fly, enabling the org to adapt its expertise to any project's unique domain, regulatory, and technical requirements.

**Approach:** Standalone skill (`ai-resource-manager`) that integrates with VTO via org-roles reference and project-state.json, rather than embedding directly into the VTO skill.

## Persona & Role Definition

**Name:** Morgan, AI Resource Manager
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

Morgan manages experts through five phases:

### 1. Assess — Identify talent gaps

- **Proactive (Stage 0-1):** After the product brief and architecture doc are produced, Morgan analyzes the domain, regulatory landscape, tech stack, and archetype to recommend an initial expert roster.
- **Reactive (any stage):** Team members flag gaps ("we need help with X"), or Morgan detects struggles in ongoing work (e.g., CTO hitting repeated blockers in a domain area).
- **Inputs:** `project-state.json`, product brief, architecture doc, tech stack, team feedback, domain signals.

### 2. Propose — Present a candidate profile

Morgan drafts a one-paragraph role description:

> "**Dr. Yara Okonkwo — Payment Systems Architect.** Specializes in PCI-DSS compliance, payment gateway integrations, tokenization patterns, and fraud detection pipelines. Would advise on transaction flow design and audit requirements."

User approves or refines before moving forward.

### 3. Define — Collaborative interview

Morgan asks 3-5 targeted questions to shape the expert's knowledge and focus:

- What specific problems should this expert solve?
- What domain knowledge is non-negotiable vs nice-to-have?
- Any specific frameworks, standards, or methodologies they should know?
- How should they interact with the existing team?

### 4. Create — Write the expert skill

Morgan generates a lightweight SKILL.md placed at `.claude/skills/experts/<name>/SKILL.md`. See "Expert Skill Structure" section below.

### 5. Manage — Bench rotation and promotion

- **Bench:** When an expert isn't needed for the current stage, Morgan moves them to inactive. They can be reactivated instantly.
- **Promote:** After a successful engagement, Morgan can package the expert as a `.skill` file for reuse in future projects. Uses the skill-creator's packaging script.

## Integration with Virtual-Tech-Org

### Updated org chart

| Role | Name | Layer |
|------|------|-------|
| CEO | Alex | Leadership (user-facing) |
| CTO | Jordan | Leadership (user-facing) |
| Domain Expert | Riley | Leadership (user-facing) |
| Resource Manager | Morgan | Leadership (user-facing) |

### Trigger points in VTO lifecycle

| Stage | Morgan's Role | Trigger |
|-------|--------------|---------|
| 0: Discovery | Listens to product brief, begins talent assessment | Automatic after brief is drafted |
| 1: Architecture | Analyzes tech stack + domain, presents initial hiring recommendations | Automatic after architecture doc |
| 2: Prototype | On standby — responds to team feedback if gaps emerge | Reactive only |
| 3: MVP | Monitors for knowledge gaps as complexity increases | Reactive + gap detection |
| 4: Production | Assesses need for security/compliance/performance specialists | Proactive for production concerns |
| Gate reviews | Reports on expert utilization — who's active, benched, recommended | Included in stage gate summary |

### project-state.json extension

```json
{
  "talent_roster": [
    {
      "name": "Dr. Yara Okonkwo",
      "role": "Payment Systems Architect",
      "status": "active|benched|promoted|released",
      "hired_stage": 1,
      "skill_path": ".claude/skills/experts/yara-okonkwo/SKILL.md",
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

### Cross-skill invocation

VTO invokes Morgan at the trigger points above via `Skill(skill: "ai-resource-manager")`. Morgan reads project state, performs the assessment, and returns recommendations. The CTO then references hired experts in ruflo workflow prompts so agents can consult them.

## Expert Skill Structure

### Directory layout

```
.claude/skills/experts/
├── yara-okonkwo/
│   └── SKILL.md
├── kai-nakamura/
│   └── SKILL.md
└── .roster.json          # Morgan's local roster index
```

### Expert SKILL.md template

```yaml
---
name: <slug>
description: >
  <Full name> — <Title>. <One-line specialization summary>.
  Hired by Morgan for <project-name>. Invoke when discussing
  <trigger topics>.
type: expert
hired_by: ai-resource-manager
project: <project-name>
---

# <Full Name> — <Title>

## Identity
<Name, title, personality, speaking style>

## Domain Expertise
<Specific knowledge areas, standards, frameworks, methodologies>

## Interaction Model
<How they relate to Alex, Jordan, Riley, and other experts.
Advisory role — not decision-making authority unless delegated by CEO/CTO.>

## Focus Areas
<What they actively contribute to in this project>

## Boundaries
<What they explicitly don't opine on>
```

### Quick hire vs promoted skill

| Aspect | Quick hire | Promoted |
|--------|-----------|----------|
| Location | `.claude/skills/experts/` | `.claude/skills/` (top-level) |
| Structure | Single SKILL.md | SKILL.md + `references/` with domain docs |
| Scope | Project-bound | Reusable across projects |
| Discovery | Loaded by Morgan on-demand | Auto-discovered by Claude Code |
| Packaging | None | `.skill` archive via skill-creator's packager |

### Promotion process

1. Morgan proposes promotion with rationale ("Yara was critical in 3 stages, this expertise will recur")
2. User approves
3. Morgan enriches the SKILL.md — adds references, generalizes project-specific language, refines the trigger description
4. Packages as `.skill` file using `scripts/package_skill.py`
5. Moves from `experts/` to top-level `skills/`

## AI Resource Manager Skill Structure

### Directory layout

```
ai-resource-manager/
├── SKILL.md                           # Main skill definition
├── references/
│   ├── expert-template.md             # Template for generating expert SKILL.md files
│   ├── assessment-criteria.md         # Framework for evaluating talent gaps
│   └── promotion-checklist.md         # Quality bar for promoting to permanent
└── scripts/
    └── manage_roster.py               # Roster CRUD operations
```

### SKILL.md frontmatter

```yaml
---
name: ai-resource-manager
description: >
  Morgan, the AI Resource Manager. Assesses talent needs, collaboratively
  hires domain expert personas, and manages the expert bench. Invoke when
  you need specialized expertise, want to assess talent gaps, or manage
  hired experts. Triggers: "hire an expert", "we need a specialist",
  "talent assessment", "who's on the team", "bench/activate expert".
tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---
```

### SKILL.md sections

1. **Persona definition** — Morgan's identity, speaking style, authority scope
2. **Proactive assessment protocol** — how Morgan analyzes project state to recommend hires (reads product brief, architecture doc, tech stack, domain signals)
3. **Hiring workflow** — the 5-phase lifecycle (Assess, Propose, Define, Create, Manage)
4. **Expert template** — the SKILL.md template Morgan uses when writing expert skills
5. **Bench management** — rules for soft cap (~3-5 active), benching criteria, reactivation
6. **Promotion pipeline** — criteria for promoting project-scoped experts to permanent skills, enrichment steps, packaging
7. **Integration hooks** — how VTO invokes Morgan at each stage, how Morgan reads/writes `project-state.json`

### manage_roster.py

Handles mechanical state management:
- Reads/writes the `talent_roster` section of `project-state.json`
- Tracks expert status transitions (active -> benched -> promoted -> released)
- Enforces the soft cap (warns Morgan when approaching 5 active)
- Generates roster summary for gate reviews

## Changes to Existing Files

### VTO updates required

1. **`org-roles.md`** — Add Morgan to the leadership table
2. **`workflow-stages.md`** — Add Morgan's trigger points at each stage
3. **`SKILL.md` (VTO)** — Add cross-skill invocation to `ai-resource-manager` at Stage 0-1 and gate reviews
4. **`init_project.py`** — Extend `project-state.json` schema with `talent_roster`, `talent_cap`, and `talent_assessments` fields

### Template updates

5. **`template/.claude/skills/`** — Add `ai-resource-manager/` directory
6. **`template/.claude/skills/experts/`** — Create empty directory (populated at runtime)
7. **`flake.nix`** — Include `ai-resource-manager` in sync-skills targets (automatic — syncs all directories)
