# Phase 3 — Specialized pickers (breadth)

**Goal:** every select-kit picker has a new-family equivalent behind its old tag; core
call sites are codemodded.

See RFC: *Roadmap › Phase 3*, *Selected-value resolution*. (Maps to dev topic P3–P9.)

## Tasks

- ☐ **Category family**: chooser / drop / selector / admin-dropdown (hierarchy via
  `@groupBy`; the "filter for more" sentinel).
- ☐ **Tag family**: tag-chooser / mini-tag / tag-drop / tag-group / intersection +
  `tag-utils`; reback FormKit's `tag-chooser`.
- ☐ **User family**: user-chooser / email-group-user-chooser + `addUserSearchOption`.
- ☐ **Long tail**: timezone, future-date, flair, form-template, group, list-setting,
  color-palette(s), period, homepage-style, font.
- ☐ **`DTopicSelect`** — the acceptance case for selected-value resolution (id→title,
  content-only trigger skeleton, `@selected` escape hatch); fold in the parked handoff.
  `TopicChooser` deprecated, not deleted.
- ☐ **discourse-ai** — port off `modifySelectKit` to the transformer API (the real-world
  acceptance test of the extension model).

## Exit criteria

- Every select-kit picker has a new-family equivalent behind a facade.
- Core call sites codemodded; each family passes the a11y acceptance gate + manual SR matrix.
