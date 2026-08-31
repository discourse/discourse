# Select-kit → ui-kit select family — progress tracker

Working trackers for the multi-phase effort to replace `select-kit` with an
accessible, async-first ui-kit select family (`SelectEngine` + `DSelect`).

- **Design source of truth:** [`SELECT-KIT-REPLACEMENT-RFC.md`](../../SELECT-KIT-REPLACEMENT-RFC.md)
  (worktree root) — the full RFC/plan. These per-phase docs are lean execution
  trackers that cross-link into it; they do not duplicate the design.
- **Public RFC:** dev.discourse.org topic #187302.

Status legend: ☐ pending · ◐ in progress · ☑ done

| Phase | Scope | Status |
|---|---|---|
| [0](PHASE-0.md) | Foundations (engine, `DSelect` single, primitives, bridge, TS) | ☑ done |
| [1](PHASE-1.md) | Complete & consolidate the core family (typeahead default, `@multiple`, windowing, chrome, groups) | ◐ in progress |
| [2](PHASE-2.md) | Extension API GA + tooling + first high-traffic migrations | ☐ |
| [3](PHASE-3.md) | Specialized pickers (category / tag / user / long tail / `DTopicSelect` / discourse-ai) | ☐ |
| [4](PHASE-4.md) | Bespoke dropdowns + test infrastructure | ☐ |
| [5](PHASE-5.md) | Ban from core/bundled + finalize deprecation | ☐ |

## Side trackers

- [`PR-SPLIT.md`](PR-SPLIT.md) — **read this before touching the branch.** `select-kit-rework` is an
  integration branch with upstream layers being peeled off into separate PRs against `main`. Carries
  the per-layer status table, the merge-`main`-in-never-rebase rule and why, the shared files that
  must be hand-edited when carving, and what not to do while the PRs are in flight.
- [`SANDBOX-A11Y-REMEDIATION.md`](SANDBOX-A11Y-REMEDIATION.md) — screen-reader and design
  feedback on the sandbox (dev topic #188731), tracked within Phase 1. Read it before touching
  `DSelect` announcements: it carries the "express states, announce events" rule, the
  announcement inventory, and the diagnoses that turned out to be wrong.
- [`A11Y-TEST-TIERS.md`](A11Y-TEST-TIERS.md) — the four automated a11y tiers, what each one can and
  cannot see, and the mutation test proving the QUnit tier is blind to the defect the system-spec
  tier catches. Read it before adding an a11y assertion, so it lands in the tier that can actually
  observe the thing.

## Roadmap-numbering note

This tracker follows the RFC/plan's **Phase 0–5** roadmap. The public dev topic #187302
lists a finer **0–11** breakdown; the mapping is:

- Plan **P1** ≈ dev P1 (complete core family).
- Plan **P2** ≈ dev P2 (extension API + tooling + FormKit/native consumers).
- Plan **P3** ≈ dev P3–P9 (the per-family migrations: category, tag, user, long tail,
  `DTopicSelect`, discourse-ai).
- Plan **P4** ≈ dev P3 (test infra) + P10 (bespoke dropdowns → `DMenu`).
- Plan **P5** ≈ dev P11 (ban + finalize).

Keep both in sync when scope shifts.
