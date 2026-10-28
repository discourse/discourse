# Phase 3 — Tags, categories and entity pickers (waves 1 and 2)

**Goal:** the hardest families join the flag first, while `DSelect` has no production consumer and
an API change is cheapest. The alpha flag goes out after wave 1.

See [`ROLLOUT.md`](ROLLOUT.md), *Waves*. See RFC: *Selected-value resolution*. Re-sequenced
2026-10-14.

## Tasks

### Wave 1: tags and categories, composer included

- ☐ **Category family:** chooser, drop, selector, search and report choosers. Two recipes,
  `DSelectCategory` and `DSelectCategoryFilter`, plus FormKit's `category-chooser` control; every
  call site is branched and the category modules joined `MIGRATED_SELECT_KIT_MODULES`. Rows render
  through `dCategoryBadge`.
  - ☑ **Engine prerequisites:** server lists without a default row ceiling (`@maxLoaded` opts
    in), an opaque paging cursor, an end edge re-armed after pages that add no rows, and an abort
    signal on `control.update` work.
  - ☑ **Call sites, the AI category suggestion and SCSS.**
  - ☑ **Recipe follow-ups:** multiple pickers keep the select's own empty text, the drop marks an
    active filter with `--filtering`, and chooser rows show topic counts.
  - ☐ **Awaiting a decision:** the drop holds its level name as a value, so its accessible name
    repeats it ("subcategories, subcategories") and no `placeholder` route exists for an empty
    level; the tag drop shares the pattern.
  - ☑ **Recipe rework (2026-10-27):** the recipes stopped re-implementing what the engine, the
    `Category` model and ui-kit helpers already do. Paging, sizing and de-duplication are the
    engine's; lazy pages come from `Category.asyncSearch` (now with `only_postable`), held ids from
    `Category.asyncFindByIds`, and the subcategory walk from `Category.asyncFindDescendants`;
    `lib/category-source` is gone. `@multiple` is forwarded unchanged (single unless `true`),
    `@exclude` never offers a category even when held, the drop searches through
    `Category.search` and draws the core caret, and rows render through `dCategoryBadge`. A
    loader that answers without a promise is no longer debounced, so no recipe sets `@debounce`.
  - ☑ **One search (2026-10-28):** the picker loads through `Category.searchCategories`, which
    answers from the site when every category is loaded and from `/categories/search` otherwise,
    with the same rules and order; families are grouped with a footer each (`@groupFooter`).
  - ☑ **VoiceOver pass and visual review** across themes and color modes (2026-10-26). Rows read
    their name, topic count ("2 topics in this category") and position; searches announce the
    result count; "and all subcategories" rows read by name. Open findings:
    - ☐ Hear again after the category cycle (2026-10-28): the descendants row became each
      family's footer, named "%{category} (%{count} topics) and all subcategories", with the
      badge drawn but hidden from the name.
    - ☐ Not yet heard: the read-only row itself. Opening the composer chooser with ArrowDown made
      the second row active and read nothing for it; the breadcrumb drop, opened with Enter, read
      its active row.
    - ☐ Most migrated call sites leave their visible label unassociated, so pickers read as
      "Options" (tags too; select-kit had the same gap).
    - ☐ Emoji-style category badges read the emoji's short name ("card_file_box Uncategorized"),
      as select-kit rows did.
    - ☐ The mobile panel's search field has no side gutter, for every DSelect.
  - ☐ **Follow-ups from the category cycle (2026-10-28):**
    - ☐ `SelectTagBase`'s `value` getter shadows `@value`, as `DSelectCategory`'s did before it
      became `selectedIds`.
    - ☐ The breadcrumb drop still has a preloaded branch and a lazy branch. Its preloaded search
      ranks through `Category.search` (slug matches too), which the shared search does not do.
    - ☐ `dCategoryBadge` with `ancestors` and `hasSubcategories` draws "+ Subcategories" after
      every ancestor (`ui-kit/helpers/d-category-link.js`), as select-kit's `category-row` did.
      The family footer draws without ancestors, so it is not affected.
- ☐ **Tag recipe rework**, the follow-up to the category rework: `cleanTagName` and
  `sortTagRows` in `lib/tag-source.ts` copy select-kit's `tag-utils` service
  (`createContentFromInput`, `sortSearchResults`); the tag filter draws its own caret from the
  `caretDownIcon`/`caretUpIcon` kind options instead of the core `caretIcon`; `SelectTagBase.multiple`
  flips DSelect's default to `true`; and `DSelectTagFilter.multiple` only turns `undefined` into
  `false`, which DSelect already does. The tag model has no search or lookup API, so the source's
  server helpers fill a real gap and stay.
- ☑ **Tag family:** tag chooser, mini tag chooser, tag drop, tag group, intersection, tag dropdown,
  and FormKit's `tag-chooser` control. Joined `MIGRATED_SELECT_KIT_MODULES`; the admin tag category
  dropdown moves with wave 3's menus. Rows reuse `dDiscourseTag` / `renderTag`. Engine prerequisites, generic
  and usable by every family:
  - ☑ **`@loadContext`:** the loader's inputs; a changed entry reloads the list (closed or open)
    without superseding pending updates. Keyboard activation is held, with a polite "Still
    loading…", while a non-reveal server load is pending.
  - ☑ **Create row:** first in the list, tied to the query on screen, a key-collision duplicate
    rule and an engine-owned "Create …" name.
  - ☑ **Disabled rows** reachable by arrow keys and announced as unavailable, with a visible
    description.
  - ☑ **Bulk add:** `selectMany` and `@parsePaste`.
  - ☑ **Selection strip** in the mobile modal, and the modal's accessible name.
  - ☑ **Compact and overflow** (`@maxVisibleChips`); display-only chips on button, static and
    mobile triggers.
- ☐ **Composer:** tag and category pickers write the same `model.tags` / category shape in both
  modes; drafts round-trip across modes.
- ☐ **discourse-ai** suggesters and the customer `modifySelectKit` plugin work through the bridge.
  The tag and category suggesters now use `select-customizations` on the composer and topic-edit
  identifiers instead of the bridge.
- ☐ **Customer `modifyClass` ports** for category-drop, tag-drop and category-chooser.
- ☐ SCSS for these families migrated.
- ☑ **Third-party notice** (render-time): notify when a legacy component of a migrated family
  renders while the flag is on, attributed from the stack. Design it against this wave's first
  family (see `ROLLOUT.md`).
- ☐ **Alpha:** staff plus a member group; member and anonymous coverage before exposure.

### Wave 2: entity pickers and ui-kit wrappers

- ☐ **User family:** user, email-group-user and group choosers on a shared user-search recipe,
  with `addUserSearchOption` and `customSearchOptions`; rewrite `DAccessControlGranteeChooser`.
- ☐ **`DTopicSelect`:** the acceptance case for selected-value resolution; fold in the parked
  handoff.
- ☐ **Long tail:** form template, timezone, flair, list setting, color, font and wizard pickers.
- ☐ **ui-kit wrappers** as one family: `d-time-input`, `d-relative-time-picker`,
  `d-future-date-input` with `FutureDateInputSelector`, `d-access-control`.

## Exit criteria

- Every family above has joined: call sites branched, state survives a mode change, specs pass in
  both modes, SCSS migrated, customization ports done.
- Each family passes the a11y acceptance gate and the manual screen-reader matrix.
