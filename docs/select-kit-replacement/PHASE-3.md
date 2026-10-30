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
  - ☑ **The drop's empty level (2026-10-28):** an empty level holds nothing and shows the level
    name as its placeholder, overridable by a `placeholder` text from the call site or a customization; the drop is named
    "Filter by: categories" / "Filter by: subcategories" and no longer repeats the level. A held
    "no subcategories" filter offers "remove filter". The breadcrumbs pass `breadcrumb-category`.
    The tag drop followed on 2026-10-29: "Filter by: tags", an empty filter that holds nothing,
    and the `breadcrumb-tag` / `breadcrumb-tag-intersection` identifiers.
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
    with the same rules and order; each family's category is followed by its footer
    (`@groupFooter`), before the rest of the family.
  - ☑ **VoiceOver pass and visual review** across themes and color modes (2026-10-26). Rows read
    their name, topic count ("2 topics in this category") and position; searches announce the
    result count; "and all subcategories" rows read by name. Open findings:
    - ☑ Heard again after the category cycle (2026-10-28): each family's footer reads once as
      "%{category} (%{count} topics) and all subcategories" with its position, at the first
      and second level; the drawn count and "+ Subcategories" are not read again, and adding
      a family announces "N added".
    - ☑ Heard (2026-10-29): the composer's read-only row reads "<name> read-only This category is
      read-only so you cannot choose it for this topic dimmed (1 of 65)". ArrowDown opens on the
      first row that can be picked, so the read-only row is heard only when the cursor moves
      onto it.
    - ☑ Category pickers with a caption are named by it (2026-10-29). `@ariaLabelledBy` points at a
      caption that has an id; FormKit fields, site settings and schema fields pass their
      caption's text as `@ariaLabel`. Still open:
      - ☑ Tag pickers (2026-10-30). The same rule; ROLLOUT "Tag call sites" lists each site. A
        picker with no caption is named "Tag", "Tags", "Tag group" or "Tag groups".
      - ☑ The panel and the mobile modal are named by the caption too (2026-10-29). Float-kit
        gained an `ariaLabelledBy` option, beside `ariaLabel`, that both modal paths and the
        positioned body honour. Before, both read "Options".
      - ☑ Pickers with no caption are named "Category", or "Categories" when they can hold more
        than one (2026-10-29). Before, the placeholder was the name ("All categories, <name>"),
        and a multiple picker with no placeholder read "Options".
    - ☑ Emoji-style category badges draw the emoji as decoration (2026-10-29); VoiceOver reads
      the name alone.
    - ☑ The mobile panel's search field lines up with the rows' content (2026-10-29).
  - ☐ **Follow-ups from the category cycle (2026-10-28):**
    - ☐ **Name ui-kit's spoken-only labels `@ariaLabel`, outside this branch** (2026-10-29).
      DSelect's `@label`/`@labelledBy` became `@ariaLabel`/`@ariaLabelledBy`, because DSelect
      never draws them. `DResizeSeparator` and the `DTabs` root use `@label` the same way and are
      already on `main`; `DTabs`' tabs and `DDragHandle` draw or show theirs and keep `@label`.
      Four production call sites, the styleguide and one outside theme component pass the
      separator's `@label`, so the rename needs a transition. Planned as a separate change.
    - ☑ `SelectTagBase`'s `value` getter shadowed `@value`; it is `selectedIds` (2026-10-29).
    - ☑ The breadcrumb drop searches through `Category.searchCategories` (2026-10-28), so slugs
      no longer match on preloaded sites. Lazy levels browse in the preloaded order and page
      as the list scrolls; the 15-row cap, its "+ N more" count and the "view all" link are
      gone.
    - ☑ The breadcrumb drop leaves out indirectly muted categories when browsing and searching,
      on every site (2026-10-29), and no longer takes `@items`. The server filters with
      `CategoryUser.indirectly_muted_condition`, which checks each row's own level and its
      parent's, so its cost follows the rows it filters: about 3 to 24 ms at 50k categories.
    - ☑ `CurrentUserSerializer#indirectly_muted_category_ids` lists through the per-row
      condition (2026-10-29): 1 to 16 ms at 50k categories, down from about 240 ms.
    - ☑ `dCategoryBadge` draws "+ Subcategories" after the category alone, not after each
      ancestor (2026-10-29).
    - ☑ **Engine: a lazy breadcrumb level asked for page 1 twice** (fixed 2026-10-29).
      - The check that a select has one source resolved its options inside the list's load, so
        the load depended on every presentation argument and on the recipe's context.
      - The first response added the level's categories to the site and changed the drop's
        arguments, so the load re-ran and cancelled the page still in flight.
      - The check's reads are now untracked, so only the load context reloads a list.
    - ☐ **Float-kit: a closing menu takes focus back from a menu opened after it.**
      - `DMenuInstance.close` (`float-kit/lib/d-menu-instance.ts`) waits for the closing
        animation, then focuses the trigger whenever the caller asked for it, as Escape does. It
        never checks whether focus has moved on in the meantime; it checks that only when the
        caller didn't ask.
      - Pressing Escape on one breadcrumb drop and opening the other within about 150 ms closes
        the new one. Letters typed next reach the global keyboard shortcuts; in a dev-site test
        that navigated to `/latest`.
      - Fix in float-kit: after the animation, return focus only if it is still unowned or inside
        the closed menu.
      - To reproduce, on a category page open the subcategory drop, press Escape, and at once
        open the category drop and type.
- ☐ **Tag recipe rework**, the follow-up to the category rework. The tag model has no search or
  lookup API, so the source's server helpers fill a real gap and stay.
  - ☑ One cleaning rule (2026-10-29): `cleanTagName` follows the server's `clean_tag`, select-kit's
    `tag-utils` calls it, and `tests/fixtures/tag-clean-parity.json` pins both sides.
  - ☑ One sort (2026-10-29): `sortTagRows` keeps an exact match first, and select-kit's
    `sortSearchResults` calls it.
  - ☑ The kit's defaults (2026-10-29): `SelectTagBase`, `DSelectTagGroup` and `DSelectTagFilter`
    forward `@multiple`, so a tag picker holds one tag unless the call site passes
    `@multiple={{true}}`.
  - ☑ The tag filter (2026-10-29): the core `caretIcon` replaces its own caret and its
    `caretDownIcon`/`caretUpIcon` kind options, its shortcuts are `@specialItems`, and an empty
    filter holds nothing and shows its placeholder.
  - ☑ Names (2026-10-30): "Tag"/"Tags" and "Tag group"/"Tag groups" by default, and
    `@ariaLabelledBy` on all three recipes.
  - ☑ Held tag groups stay listed, marked selected (2026-10-30).
  - ☑ No held-name lookup for signed-out visitors (2026-10-30); the list endpoint needs a login.
  - ☑ The tag drop caps its rows through the engine's `@maxLoaded` and its narrow hint
    (2026-10-30); the recipe's slice and "more tags" footer are gone. Paging the drop through every
    tag needs a server change and stays open.
  - ☑ The intersection is its own recipe, `DSelectTagIntersection` (kind `select-tag-intersection`,
    2026-10-30), so `DSelectTagFilter` holds one tag and no longer branches on `@multiple`.
  - ☐ Move search and lookup onto the `Tag` / `TagGroup` models, deferred until those models
    become TypeScript. `Tag.search` will return plain typed rows, and `Site.topTags` /
    `categoryTopTags` will replace the source's `topTags`.
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

- ☑ **Customizable texts (2026-10-30):** every text a select or recipe draws or speaks is a key in
  `@texts` and the `texts` customization option; the old text arguments are gone. The tag
  guidance line moved into the placeholder. Before the branch merges, remove the removed-name
  guard tagged `TODO (select-kit-rework-merge)`.

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
