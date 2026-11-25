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
    - ☑ Emoji-style category badges in the category pickers draw the emoji as decoration
      (2026-10-29); VoiceOver reads the name alone. Other badges keep the emoji's alt and title
      (`decorativeEmoji` opts in, 2026-10-31): other pickers, such as an emoji picker, need
      the emoji named.
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
    `caretDownIcon`/`caretUpIcon` kind options, its shortcuts are `@extraOptions`, and an empty
    filter holds nothing and shows its placeholder.
  - ☑ Names (2026-10-30): "Tag"/"Tags" and "Tag group"/"Tag groups" by default, and
    `@ariaLabelledBy` on all three recipes.
  - ☑ Held tag groups stay listed, marked selected (2026-10-30).
  - ☑ No held-name lookup for signed-out visitors (2026-10-30); the list endpoint needs a login.
  - ☑ The tag drop caps its rows through the engine's `@maxLoaded` and its narrow hint
    (2026-10-30); the recipe's slice and "more tags" footer are gone. Paging the drop through every
    tag needs a server change and stays open.
  - ☑ The intersection follows the filter's rules (2026-10-30): one `DSelect` in
    `DSelectTagFilter` for both modes, browsing and searching as the single drop does, with no
    tag cap and no name lookup, instead of the composer field's rules through `SelectTagBase`.
  - ☐ Move search and lookup onto the `Tag` / `TagGroup` models, deferred until those models
    become TypeScript. `Tag.search` will return plain typed rows, and `Site.topTags` /
    `categoryTopTags` will replace the source's `topTags`.
  - ☐ Rework how tag descriptions show, and decide when to show them (found 2026-11-18). The
    recipes draw a search row's description in full under its name (`tagSettings`,
    `lib/tag-source.ts:316`), in the composer field and in the tag filter alike. Select-kit
    never drew them: its rows passed the description on, but the default tag renderer leaves it
    out (`lib/render-tag.ts:49`). It looks bad today:
    - Nothing caps the length. The server sends the whole description (up to 1000 characters,
      `tags_controller.rb:624`), so one long description fills the composer's list.
    - In the narrow tag filter, even a short description wraps, and rows with and without one
      differ in height and rhythm.
    - Open question: whether descriptions belong in every tag picker at all, or only where
      choosing a tag needs the context (the composer field rather than the topic list filter),
      and whether to cut them the way badges (200 characters) and categories do.
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
- ☑ **Composer:** tag and category pickers write the same `model.tags` / category shape in both
  modes; drafts round-trip across modes (2026-10-31). Both modes save identical draft data for an
  existing tag, a created tag and a category, and each reopens the other's draft and keeps its
  tags (`composer-tags-test.js`, "Composer - Tags and category in both select modes").
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
  - ☑ `DSelectUser` over a plain `searchUsers()` and a batched `findUsersByUsernames()`, and
    `DSelectGroup` over the site's groups (2026-10-31). Held group names resolve in any case on
    the server.
  - ☑ Call sites in core and the bundled plugins branch on the flag and write the legacy
    shapes; the family's modules report legacy renders.
  - ☐ Sites that need what the engine lacks stay on select-kit, opted out of the notice:
    assign's assignee picker (open on render, suggestions on an empty query, its own search
    URL) and the workflows group field (wave 5).
  - ☑ `DAccessControl`'s add box moved to `DSelectUser` (2026-11-11). It needed a recipe
    source, not an engine change: `DSelectUser` takes a call-site `@load` that answers the
    user search's shape, and still applies its exclusion and ranking to those rows. Groups no
    permission can be granted to are listed disabled, with the reason beside the name. The
    legacy `DAccessControlGranteeChooser` is private to `DAccessControl` (#45992) and is
    deleted in the cleanup, along with the getters that only feed it.
  - ☑ A pick that closes the panel no longer re-runs the search (2026-11-11). The add box's
    pick changes `@exclude` while the panel is still open, and the engine used to reload the
    list just before it closed. A list now counts as closed once a close is requested, so the
    new context waits for the next open.
  - ☑ Assign's category groups moved to `DSelectGroup` once the engine could hold values that
    can't be removed: the global groups are `@lockedValues` (2026-11-10).
  - ☑ Held names match in any case, through the engine's opt-in `normalizeKey` (2026-10-31).
  - ☐ Make `DSelectGroup`'s search match the full name too (found 2026-11-18, deferred). Its
    rows show the full name under the group name (`d-select-group.gts:120`), but the default
    search matches the name only, so typing a full name finds nothing. `DSelectUser` does match
    the full name on its second line, through the server's user search. The legacy
    `GroupChooser` searched names only as well, so this improves on it rather than fixing a
    regression.
  - ☐ `addUserSearchOption` reaches only the legacy pickers; the new ones take `searchOptions`
    through a customization.
  - ☑ Boards modals: the "ResizeObserver loop" error was a test-only effect. A list rendered in
    place (as under tests) made the modal scroll, and FormKit stretched it to the control's
    width; the stylesheet now lets a menu or tooltip size itself, and the test stylesheet keeps
    the modal's scrollbar gutter while a list is open (2026-10-31).
  - ☑ Enter in a button-variant select's panel filter no longer also submits the modal
    (2026-10-31).
  - ☑ SCSS parity, flag-on system specs, and the visual review across themes, color modes and
    phone width (2026-10-31).
  - ☑ `user_preferences_tracking_spec.rb` (new controls, "hides tags chosen in another level")
    failed its first CI run twice and passed on retry. The spec searched the muted field for "a"
    and expected "python", which only the list shown on open holds, so it passed only when it
    looked before the search answered. It now checks the list shown on open (2026-11-10).
  - ☑ VoiceOver pass (2026-10-31, macOS, Chrome): recipient chips read their type word
    ("moderators Group", "someone@example.com Email", a user chip has none) and the removal hint;
    rows read username, name and position; the about page's pick-one user and group fields read
    their name, placeholder and FormKit description.
- ☑ **`DTopicSelect`:** the acceptance case for selected-value resolution; fold in the parked
  handoff (2026-11-10).
  - ☑ `DSelectTopic` and `DSelectTopicList` over the site search, with held topics looked up
    together through a new read-only `GET /topics/lookup` (`Topic::LookupByIds`, at most 50
    ids, visibility through the guardian, mutes ignored) and `Topic.findByIds` (2026-10-31).
  - ☑ `DSelectList` takes `@multiple={{false}}`: a pick replaces the held item, Backspace
    clears it, and the pick is announced.
  - ☑ Call sites in core and the bundled plugins branch on the flag: the site setting, both
    invite modals, `ChooseTopic` and `ChooseMessage` (five callers), the workflows topic field
    and boards' "Add topic as card"; `topic-chooser` and `topic-row` report legacy renders.
  - ☑ A focused list search with text keeps Escape from closing its modal.
  - ☑ SCSS parity and flag-on system specs (site setting, invite, boards).
  - ☑ Visual review across Foundation and Horizon, light and dark, and phone width (invite
    field, site setting, move to topic, boards): category badges now sit apart, titles line up
    with their category, and boards' list is a single choice (2026-10-31). Also the workflows
    topic filter (held topics resolved, list in the node editor's modal) and the feature-topic
    list (public topics on open, as before), light and dark.
  - ☑ VoiceOver pass (2026-10-31, macOS, Chrome). The move-to-topic list reads its label,
    placeholder and role, each row's title, category and position ("… Mathematics Calculus
    (2 of 4)"), and "selected" on a pick. The invite field reads its name, placeholder,
    description and role, and the picked topic as the list closes.
  - ☑ **A DSelect panel opened inside a DModal was silent.** The panel was portaled outside the
    modal, an `aria-modal` dialog, so Chrome left the listbox out of the accessibility tree
    (ignored reason `activeAriaModalDialog`). Every float-kit menu opened from a modal now renders
    in an outlet the dialog provides (2026-10-31); VoiceOver then reads each row with its
    position and the pick. Tooltips stay in the page's portal: `aria-describedby` reaches them
    across the boundary.
  - ☑ Pickers inside modals (move to topic or message, chat to topic, boards) use `DSelectTopic`
    instead of a list, so the modal no longer grows and shrinks with the results (2026-11-03).
    `DSelectTopic` takes `@exclude` for the current topic.
  - ☑ The profile's featured topic is a field saved with "Save changes" instead of a modal that
    saved on pick (2026-11-03); the profile update stores it under `can_feature_topic?`.
- ☐ **Long tail.** Inventoried 2026-11-12 and re-checked 2026-11-19 after `main` moved the admin
  site settings onto FormKit, counting production call sites only; none branch on the flag yet.
  - **Site settings now render in two places.** The admin settings page draws each setting
    through its FormKit field (`setting-field/*`, chosen in `lib/setting-field-registry.js` and
    `admin/lib/setting-field-types.js`). The older `site-settings/*` controls still render
    wherever a setting doesn't track changes (`useFormKit` in `site-setting.gjs`): theme
    settings, theme site settings, theme translations, and the workflows variables. A port
    covers both until `main` retires the old controls. Category, category list, tag list, tag
    group list, topic, group, group list and host list branch in both.
  - ☑ The group and group list settings (2026-11-19): all four controls branch on the flag to
    `DSelectGroup`. Disallowed groups aren't offered, everyone shows as "everyone (legacy)",
    granular permissions show logged_in_users in its place and store it back as everyone, and
    held mandatory groups are `@lockedValues`.
  - ☐ `ListSetting`, 16 sites (15 before `main` added `setting-field/host-list`), 12 left after
    the group and host lists. Each is ported one setting type at a time, on a plain `DSelect`
    over string records with `@createOption` (2026-11-19): a recipe would only wrap strings as
    records, and the rules on typed entries differ at every site.
    - Core site settings:
      - ☑ The compact, locale and file types lists (2026-11-19): the FormKit fields
        `setting-field/compact-list` and `locale-list`, and the older `site-settings/compact-list`,
        `locale-list` and `file-types-list` (which the file types field wraps), all render the
        shared `SelectStringList` (`setting-field/-internals/`). Held and removed values stay
        listed in first-held order; an empty free-text list says "No values yet"; a refused
        value says why. The file types field now passes its title and disabled state, and its
        add-types buttons follow the disabled state.
      - ☑ The older `site-settings/named-list` (2026-11-19) renders `SelectStringList` too. No
        setting in core or the bundled plugins has the named list type; the official
        discourse-geoblocking plugin has two (`geoblocking_blocked_countries` and
        `geoblocking_allowed_countries`, about 250 `{ name, value }` country choices). It has no
        FormKit field, so only the older control renders it.
      - ☑ `setting-field/group-list` and `site-settings/group-list` (see above).
      - ☑ `setting-field/host-list` and `site-settings/host-list` (2026-11-19): typed hosts,
        never with a wildcard or a `|`; a pasted list skips the ones that can't be stored.
        Both render the shared `SelectHostList` (`setting-field/-internals/`).
      - ◐ VoiceOver says "N items selected" / "selection replaced N items selected" while
        typing or clearing the query in a multi-select that lists its held values (found
        2026-11-19 on `category_colors`, 16 held). Chrome reports the changing set of
        `aria-selected` rows as a selection change; nothing was picked. Engine-wide, not
        specific to the setting pickers: check the group list and tag pickers too.
        - Diagnosed 2026-11-23 with VoiceOver and Chrome on `blocked_crawler_user_agents`
          (5 held), three variants of the option markup (`select-option-content.gts`):
          - `aria-selected` (today): typing "b" says "4 items selected", "bl" says
            "selection deleted 1 item selected", clearing says "seo spider added to selection
            5 items selected". The active row is never read while typing. Held rows read
            "mauibot selected (1 of 5)".
          - `aria-checked` alone: typing reads the active row ("Create “bl” (1 of 2)"), no
            selection talk, but held rows lose their state ("mauibot (1 of 5)").
          - `aria-checked` plus `aria-description` "selected" on held rows: typing as above,
            and held rows read "mauibot selected (1 of 5)". Both problems gone.
        - The `aria-checked` variants are withdrawn: the APG advises against mixing state
          conventions, and `aria-checked` on options is reported unsupported by VoiceOver on iOS.
        - Reference libraries, same VoiceOver and Chrome, 2026-11-23, held rows kept listed:
          - MUI Autocomplete ("Multiple values" demo) and Ariakit (multi-selectable combobox):
            same markup as ours and the same speech ("5 items selected", then "4 items
            selected" while typing).
          - React Aria ComboBox (`selectionMode="multiple"`): same markup, but it announces
            "N options available" assertively whenever the option count changes
            (`useComboBox.ts`), which talks over the selection speech. Its "States" example
            leaves held values out of the list instead, as select-kit does.
        - Conclusion: the speech is how VoiceOver and Chrome report the standard pattern, not a
          defect of ours. Possible follow-up: an assertive result-count announcement as React
          Aria does. Not decided.
        - Experiment 2026-11-23 (local patch, reverted): an assertive "N results for “q”, M
          selected" from `#resolvePendingCount`, M = held rows shown.
          - With today's 1400 ms settle delay it follows Chrome's speech ("selection deleted 1
            item selected", then "2 results for “bl”, 1 selected").
          - With no delay it lands 0.3 s after, or replaces it ("5 results for “b”, 4 selected"
            with no "4 items selected" spoken).
          - Gaps: the count after open is suppressed and deduped, so the first keystroke and
            clearing the query said nothing of ours.
        - Built 2026-11-23 (uncommitted), for multi-selects that list held rows only
          (`@multiple` without `@hideSelected`): "2 results for “bl”, 1 of them selected", "none
          of them selected", "5 results, 5 of them selected" for an empty query. Polite, same
          1400 ms delay, spoken whatever the cursor did, deduped on (N, M). A pick or removal
          suppresses the count. Four new `@texts` keys.
          - VoiceOver pass on `blocked_crawler_user_agents`: heard after Chrome's line at every
            query change, including the first keystroke and clearing ("seo spider added to
            selection 5 items selected", then "5 results, 5 of them selected"). Nothing new on
            open, on an arrowed row or on Escape.
      - ☑ Replace the colour-list name check with an explicit flag (2026-11-20). A setting
        declares `list_type: color` (site and theme settings); `category_colors` and
        `restrict_letter_avatar_colors` do. Behind the flag it edits in `ColorList`: a
        reorderable list of `DColorInput` rows (ui-kit, extracted from FormKit's color control)
        with an add row, storing 6-digit lowercase hex (switched from uppercase 2026-11-24, since
        the browser's picker reports lowercase; stored colors read in lowercase, so the first
        edit rewrites the list). The server validates every entry
        (`ColorListValidator` by default, theme settings through `ThemeSettingsValidator`).
        The compact and named list pickers no longer draw squares. With the flag off,
        `ListSetting` keeps its name check. `DReorderableList`'s create row now holds the
        handle's place, and a custom create block gets `handleSlot` for it.
      - ☑ The value list editor's add field (2026-11-19): `admin/components/value-list` serves
        48 plain `list` settings, 10 `value_list` and 1 `url_list` setting, and the options of a
        dropdown user field. Behind the flag, a list with choices adds through a `DSelect` that
        holds nothing (choices it doesn't hold, blank ones dropped), and hides it once a list that
        takes only its choices holds them all. A list without choices gets a text field and a
        `+` button, like `SimpleList`. The setting's `allow_any` now reaches the editor, so
        `allowed_onebox_iframes` refuses typed origins the server would reject, and says so.
    - ☑ `SimpleList`'s add picker for a list that takes only its choices (2026-11-19):
      `top_menu`, `post_menu`, `post_menu_hidden_items`, `share_links`, `share_quote_buttons`
      and the events plugin's `event_participation_buttons`. Behind the flag it is a `DSelect`
      that holds nothing and offers the choices the list doesn't hold, named "Add item…"; it is
      hidden once the list holds them all, and a typed value that isn't a choice says so.
    - ☑ The file size unit (2026-11-19): `FileSizeInput` serves the six `file_size_restriction`
      settings (`max_image_size_kb`, `max_attachment_size_kb`, `max_export_file_size_kb`,
      `email_total_attachment_size_limit_kb`, `system_user_max_attachment_size_kb`,
      `secure_uploads_max_email_embed_image_size_kb`). Behind the flag its unit is a static
      `DSelect` named "Unit" (KB, MB, GB), joined to the number input as the combo box was.
    - ☑ Enum settings (2026-11-19): 150 `enum` settings and `default_locale` (`locale_enum`).
      The FormKit fields drew a native select; under the flag they and the older
      `site-settings/enum` and `site-settings/locale-enum` (theme setting editors) render the
      shared `SelectEnum` (`setting-field/-internals/`), a typeahead. The registry entry names
      `newSelectControlsType: "custom"`, which `SettingDefinitionField` uses under the flag,
      since a FormKit select field can only hold a native select. A held value that is no longer
      a choice is listed as itself; a pick reports the choice's own value, numbers included.
      - None: the none row appears where it did (a bare `""` valid value, `allows_none`, or a
        definition without it that isn't required).
      - Clear: the clear button appears when the setting's default is blank and blank isn't a
        named choice, so the field can go back to "not set" without the Reset button. That is 12
        settings today (`onebox_locale`, `chat_homepage_channel`, the AI model and agent
        settings). The setting's definition now carries its `default` for this.
        `default_homepage` names its blank value ("First item in top menu"), so it's picked,
        not cleared to. Some AI model settings refuse a blank value while modules that use them
        are on; the server says which on save.
    - ☑ Core elsewhere: `groups-form-membership-fields` (2026-11-23). The email domains take
      typed values (`GroupsFormEmailDomains`; the server normalizes and validates them, so only
      `|` is refused) and the associated groups are a `DSelect` named by their label. Both are
      named by the label above them through `@id`.
    - ☑ Plugins (2026-11-23), each a plain `DSelect`:
      - discourse-ai's attachment types: typed types lowercased, named by the FormKit field.
      - data explorer's query tags: reserved tags never created, automatic tags locked with
        their own hint, and a held tag offered in its own spelling (the legacy branch offers the
        first spelling it meets, so `Ops` held beside an available `ops` read as two tags).
      - patreon's rewards: a fixed list, named "Rewards".
      - the workflows tags editor: typed tags, at most 10, named "Tags".
    - ☐ The two styleguide examples, which exist to show `ListSetting` itself.

    Lists of strings that can take new entries (`allowAny`), with `mandatoryValues`,
    `nameProperty` and `onChangeChoices`. Split the sites by shape before porting: group lists
    toward `DSelectGroup`, string lists toward `DSelect` with create, and mandatory values as
    `@lockedValues`.
  - ☑ `TimezoneInput`, 5 sites: profile preferences, local dates (desktop and mobile), the
    workflows settings and Time window field, and the events builder. Each branches on the flag
    to the new `DSelectTimezone` recipe (2026-11-24). The legacy component stays for third-party
    callers.
    - Zones are named "City, Country", using the browser's locale data for the zone's own
      country, so Paris is "Paris, France" though Monaco shares it. Each row shows the zone's
      common name, its current time and its offset, with a Tomorrow or Yesterday badge when its
      date differs from the device's. The times refresh each time the list opens.
    - Only modern zone names are offered, without moment's legacy aliases ("IST", "Japan"). A held
      alias still shows.
    - Zones are grouped by region. The device's zone leads under its own heading unless it's
      held, its region comes next, and UTC comes last.
    - A search matches the city, the country, the zone's name and common name word by word, and
      offsets such as "utc-3" or "+5:30". "gmt" also finds UTC.
    - The closed field shows the offset beside the name. The profile drops its "Use Current
      Timezone" button, since the device's zone leads the list.
    - The workflows Time window field offers "Workflow default" as a none option, and the events
      builder offers "Remove timezone".
    - ☑ Engine: a search now finds the none option by its label, ignoring case (2026-11-24). It
      used to hide whenever a query was typed.
    - ☑ Engine: on mobile, the held value now sits beside a leading icon (2026-11-24). It used to
      be centered between the icon and the caret.
  - ☑ `FormTemplateChooser`, 2 sites: the composer and the category topic template editor. Both
    branch on the flag to the new `DSelectFormTemplate` recipe (2026-11-24), which fetches the
    templates once and searches them in the list. The composer's is a single typeahead that hands
    back a number, not a one-item array, and ignores a cleared value so a topic keeps its form. The
    category's holds several and, when no templates exist, says so instead of being disabled.
  - ☑ `FlairChooser`, 1 site: account preferences. It branches on the flag to a `DSelect`
    (2026-11-24) that draws each group's flair before its name, in the list and in the field,
    through the shared `d-select__glyph` the badge recipe also uses. "(none)" is the none option,
    which clears the flair, and the "Flair" label names the field.
  - ☑ `ColorPalettePicker`, 5 sites: the theme page's light and dark palettes, interface
    preferences' light and dark palettes, and the new palette modal. Each branches on the flag to
    the new `DSelectColorPalette` recipe (2026-11-24). The legacy component stays for third-party
    callers.
    - Each row shows the palette's preview, its name and a strip of four colors (background,
      text, accent, selected). The field shows a smaller preview and the strip. Lists mixing light
      and dark palettes are grouped, light first.
    - "Active" marks the palette in use, not the one held: the theme's saved palette, the user's
      saved palette, and in the modal the default theme's palettes. The old picker marked the
      held one.
    - Interface preferences put the mode first, with its hint beside it, then the two palettes
      stacked at the form's width. The theme page's pickers drop the paintbrush icon the old
      picker never drew.
  - ☐ `ColorPalettes` (the wizard). Rows show swatches.
  - ◐ `FontSelector`: the font list setting and the wizard. Each font renders in its typeface.
    - ☑ The font list setting (2026-11-19): `setting-field/font-list` and the older
      `site-settings/font-list` render the shared `SelectFont` (`setting-field/-internals/`), a
      typeahead over the fonts sorted by name. Each row is drawn in its font, and the held font's
      class sits on the root, so the field and its input share one typeface and nothing shifts on
      focus. The `body-font-*` and `heading-font-*` classes set the same family
      (`lib/stylesheet/importer.rb:117-122`), so one class serves `base_font` and `heading_font`.
    - ☐ Engine question (found 2026-11-19): a single typeahead without a `:selection` block keeps
      the held name as the input's text, and a click puts the caret where it lands
      (`combobox-query-input.gts:169-175`), so typing appends to the name ("Interplayfair")
      instead of replacing it. Keyboard focus selects the name. With a `:selection` block the
      name is selected as it appears, so typing replaces it. Decide whether a click should select
      the name for every single typeahead; a per-picker dummy block was rejected. `DSelectTimezone`
      gets the selected name from its own `:selection` block, which draws the offset.
    - ☐ The wizard (see below).
  - ☐ The wizard's dropdown field, which renders `ColorPalettes`, `FontSelector` or `ComboBox`
    dynamically. It moves with the colors and fonts.
  - ☑ `WatchedWords`, 1 site: the admin watched word form (`watched-word-form.gjs`), found
    2026-11-24 after the inventory missed it. It branches on the flag to a multiple `DSelect`
    (2026-11-24) that takes any typed word or phrase. Like the string lists, a removed word keeps
    its row until the form saves. It doesn't offer a word the server would refuse: one longer
    than 100 characters, or one the action already watches, matched as the server does (in any
    case unless the saved word is case-sensitive). The legacy check ran only on submit and
    against the words the page's search left visible; it now reads every word in both modes.
    The field's label names its input; the legacy one pointed at an id nothing had. The specs
    run in both modes. A pasted `a|b` adds two words in both modes, so a regular expression
    with `|` has to be typed.
- ☐ **ui-kit wrappers** as one family.
  - ☑ `d-relative-time-picker` (2026-11-13): its unit select branches on the flag to a static
    `DSelect` named "Unit".
    - Deferred until the other recipes are migrated: a joined control, a number input with the
      select inside the same frame, as one field. It isn't select-kit work. Core and the bundled
      plugins have several number-and-choice pairs that could share it: this picker, the file size
      site setting input, the automation recurring period, the event reminders, and the
      subscriptions plan amount and coupon discount.
  - `d-time-input` leaves the family: draft PR #46334 on `main` gives `DDateTimeInput` a native
    time input, as core's other time fields have, and deprecates `DTimeInput`. It is cherry-picked
    here as `0592a861ca8`. Merging `main` after it lands may conflict in the events builder's
    integration test imports again: keep `pretender` and `dSelect`, drop `selectKit`. The
    third-party migration notes are in [`MIGRATION-GUIDE.md`](MIGRATION-GUIDE.md).
  - ☑ `d-future-date-input` (2026-11-16): its shortcut select branches on the flag to a typeahead
    `DSelect`, so its 7 core sites need no change. Typing matches a shortcut's name or its date
    ("nov" finds the November ones). Each row shows its date as a description, and the trigger
    shows the held one's. "Custom" is an ordinary value that reveals the date and time fields.
    Clearing now emits `null`; the old header had no clear button, so `@clearable` did nothing.
    `FORMAT` moved to `discourse/lib/time-shortcut`, re-exported from the old module.
  - ☑ `d-access-control`: the add box (2026-11-11) and the permission select both branch on the
    flag. The legacy grantee chooser goes in the cleanup.
  - ☑ `DAccessControl`'s permission menu became the `DSelectPermission` recipe (2026-11-12,
    `0bc11e587c0`), with no flag: the caller's permissions as `@options`, then Remove as an
    action option at the end, after a divider. The old `DAccessControlPermissionMenu` module is
    deleted.
  - Trailing action options (audited 2026-11-11, core and bundled plugins): no select-kit value
    select ends with an action; theirs all lead (the AI suggest options, the drops'
    shortcuts). The recipe returns Remove from `@extraOptions` with `position: "end"` and
    `divider: "before"`. The other `DMenu` value pickers, two of which also end with an action,
    are tracked in PHASE-4, wave 3.

## Exit criteria

- Every family above has joined: call sites branched, state survives a mode change, specs pass in
  both modes, SCSS migrated, customization ports done.
- Each family passes the a11y acceptance gate and the manual screen-reader matrix.

## Before the branch merges

- ☐ Remove the removed-name guard tagged `TODO (select-kit-rework-merge)` (see "Customizable
  texts" above).
- ☐ Move the ad-hoc selectors that land on `main` while the branch is open to the matching
  recipe or `DSelect` component, behind the flag like every other call site. Check each `main`
  merge for new pickers built on `DMenu` or `DMultiSelect`, not only new select-kit uses. Known:
  - ☑ The upcoming change group control (`upcoming-change-group-control.gjs`, #45142, merged
    in `ebd1d84f27e`) branches on the flag to `DSelectGroup` (2026-11-10): `@emit="names"`,
    `@everyone`, `@exclude` and `@lockedValues` for the groups that can't be removed. Its
    system spec runs in both modes. #45929 moved the legacy branch to `DMultiSelect`; the
    merge in `1d0e7629f72` kept the flag branch and dropped `EmailGroupUserChooser`.
  - ☑ The DSA statement's community rule field (`dsa-moderation-details.gjs`, merged in
    `ebd1d84f27e`): a FormKit custom field that picks one rule, shown with its explanation,
    from a `DMenu` with a `DDropdownMenu`. #45679 moved it into a shared
    `dsa-classification-select.gjs` (merged in `1d0e7629f72`). It branches on the flag to a
    typeahead `DSelect` (2026-11-12): admins can configure any number of rules, so it searches
    by rule name, and each explanation is its option's description. #46652 deleted
    `dsa-classification-select.gjs` and moved the legacy branch to a FormKit menu field; the
    merge in `77a47932da2` kept the flag branch and switches the whole field, since the two
    branches need different FormKit field types.
  - ☑ The DSA statement's category field (`dsa-moderation-details.gjs`, #46652, merged in
    `77a47932da2`). It was a FormKit select; it is now a FormKit menu field that picks one of
    the EU DSA statement categories, marks the current one with a check, and names it to screen
    readers through a hidden label in the help tooltip. It branches on the flag to a typeahead
    `DSelect` (2026-11-23), like the rule field next to it. The combobox shows the held category
    as its value, so the new branch drops the hidden label. The help tooltip's link to the
    category definitions can't be reached from the keyboard, so the panel's `:footer` carries it
    too, where Tab from the field lands. The classification specs, core and discourse-ai, run in
    both modes.
  - ☑ discourse-ai's feature access groups (`ai-feature-agent-groups.gjs`, #45998, merged in
    `1d0e7629f72`) branch on the flag to `DSelectGroup` (2026-11-12), offering the groups the
    editor looks up, named after the feature.
  - ☑ The blog's co-author field (`blog-publication-panel.gjs`, #46193, merged in
    `155c58773ce`): a FormKit custom field with a `UserChooser` capped at 10 users that
    excludes the article's author. It branches on the flag to a multiple `DSelectUser`
    (2026-11-23) with `@maximum={{10}}` and the topic's owner in `@exclude`, offering users
    only, as the legacy chooser did.
  - ☑ discourse-ai's agent and LLM pickers (`ai-agent-llm-selector.gjs`, merged in
    `155c58773ce`). They were already `DropdownSelectBox` uses; #46469 turned them into an
    `AgentLlmDropdown` subclass that prepends a heading row through a select-kit collection
    and lets clicks on the heading's settings link through. They branch on the flag to two
    `DSelect`s (2026-11-24). A list of more than three options gets the button variant's
    search field, a shorter one the static variant. On the conversations page the heading
    becomes a `:listHeader`, and the settings link moves to the `:footer`, admins only. Agents
    show their descriptions, and the triggers keep the legacy flat look. The homepage and agent
    specs run in both modes.
  - Checked in `ebd1d84f27e` and not ad-hoc: the blog plugin's `DMenu`s are action menus, and
    the new `ComboBox` in discourse-ai's spam settings is the generic select-kit control,
    covered by the long tail.
- ☐ Decide how `DAccessControl` confirms a removal to screen readers (found 2026-11-12). Not a
  `DSelect` issue. VoiceOver reads the row that takes focus first and speaks "Removed {name}"
  after it, which lands late. Rejected: an assertive announcement (it cuts off the new row's
  readout), moving focus after the announcement (focus falls to the page and the message is
  lost), and `ariaNotify()` (not in every supported browser). Moving focus about 1.2 s later
  put the message first, at the cost of a wait for every keyboard user. The open idea is an
  Undo row that takes focus, named "Undo removing {name}", so the confirmation is the focused
  element; it needs a design decision on when the row goes away.

`DSelectTopicList` stays (decided 2026-11-10): it has no callers since the pickers inside modals
moved to `DSelectTopic` (2026-11-03), and a use case for it is planned.
