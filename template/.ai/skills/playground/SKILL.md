---
name: playground
description: Build a self-contained interactive HTML playground with controls, live preview, and generated prompt output.
---

# Playground Builder

A playground is a self-contained HTML file with interactive controls, a live preview, and generated prompt output. The user explores visually, then passes the prompt to an agent without requiring the agent to see the playground.

## Use When

When the user asks for an interactive playground, explorer, or visual tool for a topic — especially when the input space is large, visual, or structural and hard to express as plain text.

## Workflow

1. **Identify the playground type** from the user's request.
2. **Load the matching template** from `templates/`:
   - `templates/design-playground.md` — Visual design decisions (components, layouts, spacing, color, typography)
   - `templates/data-explorer.md` — Data and query building (SQL, APIs, pipelines, regex)
   - `templates/concept-map.md` — Learning and exploration (concept maps, knowledge gaps, scope mapping)
   - `templates/document-critique.md` — Document review (suggestions with approve/reject/comment workflow)
   - `templates/diff-review.md` — Code review (git diffs, commits, PRs with line-by-line commenting)
   - `templates/code-map.md` — Codebase architecture (component relationships, data flow, layer diagrams)
3. **Follow the template.** Adapt the closest one when no exact type fits.
4. **Verify behavior.** Open the file with an available browser tool when practical; otherwise report its local path. Check initial render, controls, presets, prompt updates, copy feedback, and narrow viewport layout.

## Required Behavior

- **Single HTML file.** Inline all CSS and JS. No external dependencies.
- **Live preview.** Updates instantly on every control change. No "Apply" button.
- **Prompt output.** Natural language, not a value dump. Only mentions non-default choices. Includes enough context to act on without seeing the playground. Updates live.
- **Copy button.** Clipboard copy with brief "Copied!" feedback.
- **Sensible defaults + presets.** Looks good on first load. Include 3-5 named presets that snap all controls to a cohesive combination.
- **Coherent theme.** Match the domain and repository design conventions; use system UI fonts and monospace for code/values unless the project says otherwise.

## State Pattern

Keep a single state object. Every control writes to it, every render reads from it.

```javascript
const state = { /* all configurable values */ };

function updateAll() {
  renderPreview(); // update the visual
  updatePrompt();  // rebuild the prompt text
}
// Every control calls updateAll() on change
```

## Prompt Pattern

```javascript
function updatePrompt() {
  const parts = [];

  // Only mention non-default values
  if (state.borderRadius !== DEFAULTS.borderRadius) {
    parts.push(`border-radius of ${state.borderRadius}px`);
  }

  // Use qualitative language alongside numbers
  if (state.shadowBlur > 16) parts.push('a pronounced shadow');
  else if (state.shadowBlur > 0) parts.push('a subtle shadow');

  prompt.textContent = `Update the card to use ${parts.join(', ')}.`;
}
```

## Avoid

- Value-dump prompts; write a natural, standalone instruction.
- Too many visible controls; group concerns and collapse advanced options.
- Stale previews; every change must re-render immediately.
- Empty initial state; provide useful defaults and presets.
- External dependencies; the file must work offline.
- Context-dependent output; include enough for an agent to act without the playground.
