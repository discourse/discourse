---
name: discourse-select-engine
description: Use before changing the DSelect engine or its tests. The engine is the DSelect and DSelectList components and everything under frontend/discourse/app/ui-kit/select outside recipes/, plus app/assets/stylesheets/common/components/d-select.scss. Covers getting approval, keeping the internals small, changing or pruning existing tests before adding new ones, test-first evidence, and what the handoff reports.
---

# Changing the DSelect engine

The engine is what every select is built on: the `DSelect` and `DSelectList` components
(`d-select.gts`, `d-select-list.gts`), the headless engine, coordinators and parts under
`frontend/discourse/app/ui-kit/select/` (everything except `recipes/`), and `d-select.scss`.
Recipes are not the engine; `.skills/discourse-select-recipes` covers them.

The engine is large and so are its suites. Every change should leave both no bigger than the
behaviour needs, and preferably smaller.

## 1. Get approval first

Change the engine only when the user has approved that change. Recipe work, a port or a failing
assertion is not approval. When a call site seems to need engine support, first try changing the
call site or recipe, or ask whether the requirement is right. Never bring legacy select-kit
behaviour into the engine to reach parity: the new components were built to avoid some of it.
Don't let a delegate edit engine files either.

## 2. Simplify, don't layer

Before writing code, say what the change lets you delete or merge, not only what it adds:

- Prefer a change that removes a path, a field, an argument or a special case.
- Reuse the state the engine already has before adding tracked state, an argument or plumbing
  between parts.
- When the same fragment repeats across parts, change all of its copies the same way, or fold
  them into one.
- Put presentation in the stylesheet when it can live there, rather than in template arguments.
- If the only way forward adds a mechanism, say so, explain why nothing smaller works, and get
  approval for that mechanism.

## 3. Tests: change before adding

When behaviour changes, existing tests usually already cover it.

1. Before writing a test, search the engine's unit and integration suites for the behaviour
   (`frontend/discourse/tests/integration/ui-kit/select`, `frontend/discourse/tests/unit`).
2. Rewrite a test whose premise changed, and rename it to say what it now pins. Delete a test
   that now repeats another one.
3. Add a new test only for behaviour no existing test covers.
4. Pin behaviour a user or call site can observe, not the implementation.

## 4. Test first

Write or change the test, run it, and see it fail for the stated reason before writing the fix.
After the fix, plant the defect again, or a plausible weaker version of the fix, to confirm the
test catches it. A test never seen failing has not been shown to test anything.

## 5. Handoff

Report:

- what the change deleted or merged, and what it added;
- the tests changed, removed and added, by name;
- what was verified only by eye, such as styling, and how.
