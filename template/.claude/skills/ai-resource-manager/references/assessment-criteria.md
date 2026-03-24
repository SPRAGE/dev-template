# Talent Assessment Criteria

Quinn uses this framework to evaluate talent gaps. Assessment happens proactively at Stages 0-1 and reactively at any stage.

## Assessment Inputs

Quinn reads these sources to identify talent needs:

1. **project-state.json** — archetype, tech stack, current stage, risk register, team composition
2. **product-brief.md** — problem domain, target users, constraints, domain context (Riley's section)
3. **architecture.md** — tech stack decisions, data model, security model, domain requirements
4. **Team feedback** — explicit requests from CEO, CTO, or Riley ("we need help with X")
5. **Gap signals** — CTO reporting repeated blockers, Riley flagging domain complexity beyond generalist knowledge

## Domain Analysis

Evaluate the project's domain for specialist needs:

| Signal | Indicates | Example |
|--------|-----------|---------|
| Regulatory requirements in product brief | Compliance specialist | HIPAA, PCI-DSS, GDPR, SOX |
| Industry-specific data formats | Integration specialist | HL7/FHIR, FIX protocol, EDI |
| Domain-specific workflows | Workflow/process expert | Claims processing, supply chain, trading |
| Multi-jurisdiction operation | Legal/regulatory expert | Cross-border payments, international shipping |
| Safety-critical system | Safety/reliability engineer | Medical devices, automotive, aviation |
| Complex user research needs | UX research specialist | Accessibility, localization, cultural adaptation |

## Tech Stack Analysis

Evaluate whether the chosen tech stack requires specialized expertise:

| Signal | Indicates | Example |
|--------|-----------|---------|
| Uncommon language/framework | Language specialist | Elixir/Phoenix, Rust/WASM, Haskell |
| Complex infrastructure | Infrastructure specialist | Kubernetes, service mesh, multi-cloud |
| Specialized database | Data specialist | Graph DB, time-series, vector DB |
| ML/AI components | ML engineer | Model serving, training pipelines, embeddings |
| Real-time/streaming | Streaming specialist | Kafka, WebSocket, CRDT |
| Cryptography requirements | Security/crypto specialist | E2E encryption, key management, HSM |

## Gap Detection (Reactive)

During active development, watch for these signals:

| Signal | Source | Action |
|--------|--------|--------|
| CTO reports repeated blockers in a domain area | CTO status updates | Propose specialist for that area |
| Riley flags knowledge limits | Riley domain assessment | Propose deeper domain expert |
| Security audit reveals domain-specific concerns | Ash (Security) findings | Propose compliance/security specialist |
| Performance issues tied to domain patterns | Taylor (Performance) findings | Propose domain-specific performance expert |
| User requests domain expertise directly | User message | Assess and propose |

## Prioritization

When multiple gaps are identified, prioritize by:

1. **Blocking** — Is work stalled without this expertise? (Highest priority)
2. **Risk** — Does the risk register contain items this expert would mitigate?
3. **Stage relevance** — Is the expertise needed for the current or next stage?
4. **Breadth of impact** — How many features/components does this expertise touch?
5. **Availability of alternatives** — Can Riley or the existing team cover this adequately?

## Assessment Output

For each recommended hire, Quinn produces:

1. **One-paragraph candidate profile** — name, title, specialization summary
2. **Justification** — which signals triggered the recommendation
3. **Priority** — blocking / high / medium / low
4. **Stage relevance** — when this expert is most needed
5. **Overlap check** — does this overlap with Riley or existing experts?
