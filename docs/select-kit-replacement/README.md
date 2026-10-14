# Select-kit → ui-kit select family — progress tracker

Working trackers for the multi-phase effort to replace `select-kit` with an
accessible, async-first ui-kit select family (`SelectEngine` + `DSelect`).

- **Design source of truth:** [`SELECT-KIT-REPLACEMENT-RFC.md`](../../SELECT-KIT-REPLACEMENT-RFC.md)
  (worktree root) — the full RFC/plan. These per-phase docs are lean execution
  trackers that cross-link into it; they do not duplicate the design.
- **Rollout:** [`ROLLOUT.md`](ROLLOUT.md) — how the replacement ships: one upcoming-change
  flag, a switch at each core call site, least-ready-first waves, promotion gates. It supersedes
  the RFC's "Migration strategy" section, and phases 2–5 below follow its waves (re-sequenced
  2026-10-14).
- **Public RFC:** dev.discourse.org topic #187302.

Status legend: ☐ pending · ◐ in progress · ☑ done

| Phase | Scope | Status |
|---|---|---|
| [0](PHASE-0.md) | Foundations (engine, `DSelect` single, primitives, bridge, TS) | ☑ done |
| [1](PHASE-1.md) | Complete & consolidate the core family (typeahead default, `@multiple`, windowing, chrome, groups) | ◐ in progress |
| [2](PHASE-2.md) | Rollout foundations: flag, switch plumbing, deprecations, bridge contract, test infra (wave 0) | ☐ |
| [3](PHASE-3.md) | Tags, categories (composer included) and entity pickers (waves 1–2) | ☐ |
| [4](PHASE-4.md) | Menu-shaped selects, action menus, generic and native selects (waves 3–4) | ☐ |
| [5](PHASE-5.md) | Plugin subclasses, promotion to permanent, cleanup and ban (wave 5) | ☐ |

## Side trackers

- [`PR-SPLIT.md`](PR-SPLIT.md) — **read this before touching the branch.** `select-kit-rework` is an
  integration branch with upstream layers being peeled off into separate PRs against `main`. Carries
  the per-layer status table, the merge-`main`-in-never-rebase rule and why, the shared files that
  must be hand-edited when carving, and what not to do while the PRs are in flight.
- [`SANDBOX-A11Y-REMEDIATION.md`](SANDBOX-A11Y-REMEDIATION.md) — screen-reader and design
  feedback on the sandbox (dev topic #188731), tracked within Phase 1. Read it before touching
  `DSelect` announcements: it carries the "express states, announce events" rule, the
  announcement inventory, and the diagnoses that turned out to be wrong.

## Roadmap-numbering note

This tracker follows the RFC/plan's **Phase 0–5** roadmap. The public dev topic #187302
lists a finer **0–11** breakdown; the mapping is:

- Plan **P1** ≈ dev P1 (complete core family).
- Plan **P2** ≈ dev P2 (extension API + tooling + FormKit/native consumers).
- Plan **P3** ≈ dev P3–P9 (the per-family migrations: category, tag, user, long tail,
  `DTopicSelect`, discourse-ai).
- Plan **P4** ≈ dev P3 (test infra) + P10 (bespoke dropdowns → `DMenu`).
- Plan **P5** ≈ dev P11 (ban + finalize).

Phases 2–5 were re-sequenced into the rollout waves on 2026-10-14, so this mapping to the dev
topic is out of date until the topic is updated. Keep both in sync when scope shifts.
