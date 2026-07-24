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
