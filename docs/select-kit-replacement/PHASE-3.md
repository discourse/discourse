# Phase 3 — Tags, categories and entity pickers (waves 1 and 2)

**Goal:** the hardest families join the flag first, while `DSelect` has no production consumer and
an API change is cheapest. The alpha flag goes out after wave 1.

See [`ROLLOUT.md`](ROLLOUT.md), *Waves*. See RFC: *Selected-value resolution*. Re-sequenced
2026-10-14.

## Tasks

### Wave 1: tags and categories, composer included

- ☐ **Category family:** chooser, drop, selector, search and report choosers. Two recipes,
  `DSelectCategory` and `DSelectCategoryFilter`, plus FormKit's `category-chooser` control; every
  call site is branched and the category modules joined `MIGRATED_SELECT_KIT_MODULES`. Rows reuse
  `categoryLinkHTML`.
  - ☑ **Engine prerequisites:** server lists without a default row ceiling (`@maxLoaded` opts
    in), an opaque paging cursor, an end edge re-armed after pages that add no rows, and an abort
    signal on `control.update` work.
  - ☑ **Call sites, the AI category suggestion and SCSS.**
  - ☑ **Recipe follow-ups:** multiple pickers keep the select's own empty text, the drop marks an
    active filter with `--filtering`, and chooser rows show topic counts.
  - ☐ **Awaiting a decision:** the drop holds its level name as a value, so its accessible name
    repeats it ("subcategories, subcategories") and no `placeholder` route exists for an empty
    level; the tag drop shares the pattern. Also the source's paging shape and the "and all
    subcategories" rows.
  - ☐ **VoiceOver pass and visual review** across themes and color modes.
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
