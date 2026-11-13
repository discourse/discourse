---
name: discourse-select-recipes
description: Use when writing, porting or reviewing a DSelect recipe (frontend/discourse/app/ui-kit/select/recipes) or the data access behind one. Covers the survey to do before writing code (engine, domain model, ui-kit helpers), the red flags that mean a recipe is re-implementing something that already exists, the rule to ask before adding what seems missing, and the review gate before handing a recipe off.
---

# DSelect recipes

A recipe is a `DSelect` specialized for one kind of value. Its job is small: state the domain's
rules (which records are offered, in what order, with what labels and settings) and render its
options. The engine already owns loading, paging, sizing, selection and presentation, and the domain model
usually owns lookup and search. Most recipe bugs come from re-implementing one of those.

## 1. Survey before writing

Do all of this before the first line of recipe code, and note what you found:

1. **The engine.** Read "Options and records" and "What the engine already does" (under
   Recipes) in `frontend/discourse/app/ui-kit/select/README.md`, then the argument docs in
   `d-select.gts` for anything you plan to rely on. The select lists **options**; your data are
   **records**, handed back as they are; how the select is set up is its **config**. Name the
   recipe's own inputs by their domain (`group`, `tag`, `category`), never "record" or "item".
2. **The domain model.** Read the model's statics and getters, not only its fields. For
   categories that is `frontend/discourse/app/models/category.ts` (`findById`, `findByIds`,
   `findByIdsOrLoad`, `asyncFindByIds`, `findUncategorized`, `search`, `searchCategories`,
   `matchesSearch`, `localSearchCategories`, `asyncSearch`, `asyncFindDescendants`,
   `listByActivity`, `sortCategories`) and its instance getters (`descendants`, `subcategories`,
   `isParent`, `canCreateTopic`, `isUncategorizedCategory`). That list is a start, not the
   whole model. Note what each member caches, what it writes to the site, and its defaults
   (`search` returns five matches unless given a `limit`).
3. **Shared helpers.** `frontend/discourse/app/ui-kit/helpers/` (domain badges such as
   `dCategoryBadge`, `dDiscourseTag`), `lib/helpers.ts` (`makeArray`), `lib/utilities.js`
   (`removeAccents`), `lib/array-tools.js`.
4. **The nearest shipped recipe**, as a pattern for structure only. Never copy its helpers or
   its getters: they may be the mistakes this skill lists.
5. **The old component**, for the behaviour users rely on. Port the intent; do not port a
   behaviour just because the old component had it (hiding held options, a hand-drawn caret, a
   default flipped to multiple).

## 2. Red flags

Each of these means existing code is being re-implemented. Use the alternative, or ask.

| In the recipe | Use instead |
|---|---|
| Slicing records by `offset`, computing `total`/`hasMore` from positions, a page size constant | Return the full array from a client loader; for a server, return `{ options, total, cursor }` and let the engine page |
| A cursor object that counts received records | `total` (or `hasMore` when the page and the records counted differ); the engine counts |
| A cursor that counts pages, or a page computed from `offset` | `opts.page`, the engine's 1-based count of settled pages |
| One loader for a preloaded site and another for a lazy one, or a `lazy` flag in `@loadContext` | One loader over a model static that answers with a value or a promise (`Category.searchCategories`); a value keeps the list synchronous |
| De-duplicating records (`findIndex`, `Set` of seen ids) across pages | The engine de-duplicates by key |
| Extra options after a record (an action on its family, a "more" option), or `hasMore` given only because of them | Group the family with `@groupBy` and return an action option from `@groupFooter`; the engine places, keys and counts it, and never pages on it. An action after the whole list is an `@extraOptions` entry with `position: "end"` |
| Injecting extra options into a page and correcting `total` | `@extraOptions`; a source option with an extra option's value is dropped. `@extraOptions` is synchronous, so a lazy loader resolves the records those options need before it answers; the list is built only after the load resolves |
| Checking `signal`, `throwIfAborted`, aborting requests, caching responses | The engine drops superseded responses; models cache. Inside `control.update`, call the scope's methods after the work: they do nothing once a later change supersedes it, so no abort handling is needed |
| `@debounce={{…}}` | The engine debounces only loaders that answer with a promise. Older recipes set it because the engine once debounced every `@load`; remove it |
| A getter that only changes an engine default (`multiple`, `?? false`) | Forward the argument unchanged; call sites pass what they mean |
| `Array.isArray(x) ? x : [x]`, `x == null ? [] : …` | `makeArray` |
| A reload key derived from the held value | Fix the call site's contract; `@loadContext` lists real loader inputs |
| `_expanded` state, `onShow`/`onClose` to swap a caret, `@showCaret={{false}}` | `@caretIcon={{hash open closed}}` |
| Ranking, accent folding or matching code | The model's `search`, `removeAccents`. A matching rule the model does not have (for example matching a parent's name) stays in the recipe, with a test, and still folds accents through `removeAccents` |
| A `lib/*-source` module wrapping the model's search and lookup | Call the model directly |
| Calling a helper's internals (`categoryLinkHTML`) instead of the ui-kit helper | The `ui-kit/helpers/` helper |
| Hiding held options (`@hideSelected`) to match the old component | Keep held options listed and selected, for assistive technology |
| Behaviour written into a record's fields (`disabled`, `description`, `sticky`, `onSelect`), or a copy made to add them (`{ ...record, disabled: true }`) | `selectOption(record, settings)`, or `option.with(settings)` in a content step. A record's fields are data and never change what its option does |
| Projecting a caller's records into new objects only to rename fields or add a description | List the caller's records as they are, with `@valueField`/`@labelField` and a `description` setting, so `option.record` is what the caller passed. A recipe that must build its own record carries the caller's settings over with `selectOption(ownRecord, option.settings)` |
| Reading `option.name` (or any record field) off an option in a content step, group builder or block | `option.record.name`; an option is not its record, and JavaScript gives `undefined` without a warning |

A recipe may still need code of its own: its domain's rules, labels and record shape, and genuinely
new helpers (for example decoding a transformed description). Those are fine once the survey
shows nothing covers them.

## 3. Ask before adding

If the engine, the model or a helper seems to lack something the recipe needs, stop and ask the
user before writing it. Say what you looked at and what is missing. Engine changes always need
approval. Never add a recipe-local workaround for an engine gap. That includes using an
extension point such as `@extraOptions` to restore something the engine leaves out on purpose
(a "none" option in a multi-select, for example): that is a question about the engine, not recipe
code.

## 4. Tests

- Test behaviour a user or call site can observe: which options are offered, what is emitted, what
  the server is asked. Do not pin paging mechanics the engine owns.
- A server stub answers like the endpoint does: by the ids or parameters it was sent, not with a
  fixed body that ignores the request.
- A test that pins removed behaviour is changed openly, and its new name says what it now pins.

## 5. Review gate

Before handing a recipe off (or approving one), list every function, getter and module-level
helper it defines. For each, write one line naming why no existing engine argument, model
method or helper covers it. A callback the engine requires (`load`, `resolveValues`,
`onChange`) is justified by its contract, but its body is reviewed like any other code. Anything
you cannot justify that way is a finding. Include the list in the handoff.
