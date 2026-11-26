# Proposal: replace `@required` and `@clearable` with `@clearMode` and `@ariaRequired`

Status: approved and implemented. DSelect is pre-release, so this renames freely and keeps no
aliases.

## Problem

`@required` mixes behaviour with form semantics. On a single select it:

1. stops Backspace and Delete from emptying the value (`interaction-coordinator.ts`,
   `field-keyboard.ts`, both through `engine.hasRemovableValue`);
2. hides the clear control (`variant-presenter.ts`, `showClear`);
3. forbids `@clearable` and `@noneOption`, with a development assertion at the call site
   (`select-engine.ts`) and for extensions (`customizations.ts`);
4. sets `aria-required="true"`, on the root, or on the query input for desktop typeahead
   (`d-select.gts`, `single-trigger-display.gts`).

Menus that only need 1 to 3 (sorts, layouts, a poll rank) also get 4, so screen readers announce
"required" on controls that are not form fields and submit nothing. It does nothing else: no
validation, no blocked submit, no forced initial value.

`@clearable` sounds like it decides whether the value can be emptied, but it only shows the
× control. Keyboard clearing is always on unless `@required`, so the two arguments together encode
three states with one invalid combination.

## Proposal

### `@clearMode`: how the user can empty the value

Named as a setting so it can't be read as a verb (`@clear="never"` reads like an instruction, and
`@clearing` like an action in progress).

| Value | Backspace/Delete empties it | × control | `@noneOption` allowed | Replaces |
|---|---|---|---|---|
| `"keyboard"` (default) | yes | no | yes | no argument |
| `"button"` | yes | yes | yes | `@clearable={{true}}` |
| `"never"` | no | no | no (assertion) | `@required={{true}}`, behaviour only |

- Keyboard clearing stays on in every state that allows emptying, so a reader can never reach a
  value they cannot leave. That is why there is no "button only" state.
- It is an enum, not a three-state boolean: `undefined` and `false` meaning different things
  breaks silently when a template passes a getter that returns `undefined`.
- Multi-select: Backspace still removes the last chip in every state. Only `"button"` matters
  there, showing the "Clear all" control. `"never"` adds no lock to chips.
- Extensions: `current.clearMode` replaces `current.clearable` and `current.required`. An extension
  cannot loosen a call site's `"never"`, and the existing assertion against a none option on a
  value that can't be emptied keeps its meaning.

### `@ariaRequired`: say the field is required

- A boolean that only sets `aria-required="true"`, routed as today: the root, or the query input
  on desktop typeahead. That routing is why it is an argument and not a plain attribute.
- No behaviour, by design. It doesn't remove a none option or stop the value being emptied: a form
  can let the reader empty a required field, then validate it and show an error message. Whether
  the value can be emptied is `@clearMode`'s job alone.
- A required form field that must keep its value passes both `@clearMode="never"` and
  `@ariaRequired={{true}}`.
- FormKit doesn't set `aria-required` on any of its controls today, so this change doesn't wire it
  into the two DSelect ones either; doing so alone would make them the exception. Announcing
  required fields across FormKit is follow-up work for FormKit as a whole, which can then pass
  `@ariaRequired` to its DSelect controls.

### No combined state

`@clearMode` has no fourth value that also sets `@ariaRequired`. The two are independent: in a form,
"required" means the field must hold a value when submitted, not that the user can never empty it.
All four combinations occur:

| | not required | required |
|---|---|---|
| can't be emptied | menus: sort, layout, rank | design wizard fonts |
| can be emptied | most pickers | required FormKit fields, checked on submit |

FormKit's category chooser shows the × control on every field (`fk/control/category-chooser.gjs`),
including one with a `required` rule. A combined state would cover one cell, still need
`@ariaRequired` for the others, and give two spellings of the same meaning for reviewers and
extensions reading `current.clearMode` to reconcile. It would save little typing either way.

## Migration

- **Engine:** `config.required` and `config.clearable` become `config.clearMode` and
  `config.ariaRequired`. `hasRemovableValue` reads `clearMode !== "never"`, and `showClear` reads
  `clearMode === "button"`. Texts and the clear control's name are unchanged.
- **Call sites** (search hits, each to be confirmed as a DSelect during the change):
  - 46 `@clearable={{true}}` hits, outside tests and the styleguide, become `@clearMode="button"`;
  - computed values (`@clearable={{not this.required}}`, `{{not this.multiple}}`,
    `{{this.clearable}}`) map to the matching enum value;
  - menus with `@required={{true}}` (filter controls sort, nested replies sort, sidebar edit
    filter, composer translation selector, composer editor, poll rank, gist toggle) become
    `@clearMode="never"`;
  - form fields with `@required={{true}}` (design wizard fonts, workflows settings) get
    `@clearMode="never"` plus `@ariaRequired={{true}}` where the field really is required; each is
    decided at its call site;
  - recipes that forward `@clearable` or `@required` (topic, badge, category, user, group,
    timezone, font, color palette, form template, and `setting-field` `select-enum`) forward
    `@clearMode` and `@ariaRequired` instead, and their Signatures change with them.
- **Tests:** about 95 lines in 20 files under `tests/integration/ui-kit/select` and `tests/unit`
  reference the two arguments. New tests cover each `@clearMode` state, keyboard and control, single
  and multi, the extension assertion, and `@ariaRequired` on both routing targets.
- **Docs:** the argument docs in `d-select.gts`, the select README, the ui-kit guide, the
  styleguide examples, and the `discourse-select-recipes` skill.

## Order

1. Engine change with its tests, test-first.
2. Call sites and recipes, in the same commit so the branch never holds a half-renamed API.
3. Resume the gist toggle and agent list ports on `@clearMode="never"`.
