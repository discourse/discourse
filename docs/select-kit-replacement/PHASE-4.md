# Phase 4 — Menus, generic selects and native selects (waves 3 and 4)

**Goal:** the menu-shaped controls land on the right primitive, and the high-volume generic and
native selects join the flag.

See [`ROLLOUT.md`](ROLLOUT.md), *DMenu or DSelect* and *Waves*. Re-sequenced 2026-10-14.

## Tasks

### Wave 3: menu-shaped value selects and action menus

- ☐ **DSelect:** the group dropdown, and value-type `DropdownSelectBox` uses (composer
  translation selector, sidebar edit filter). The notification-level family (group settings'
  `NotificationsButton` and its plugin and theme subclasses) waits on the route decision in
  `ROLLOUT.md`.
  - ☑ Group dropdown (`components/group-navigation.gjs`). The call site configures
    `DSelectGroup` and navigates on a pick, as the breadcrumbs do with the category filter; the
    styleguide's group nav pills example still renders the old one. Seven theme and plugin
    stylesheets restyle `.select-kit.combo-box.group-dropdown`, and one customer plugin records
    analytics on clicks on its `.select-kit-row`, which needs a customer port.
  - ☑ Composer translation selector (`components/composer-container.gjs`). A plain `DSelect`
    at the call site, with no recipe. It can't be emptied (`@clearMode="never"`), because
    emptying it blanked the typed translation; the old control's "Select translation" row did
    the same. The system specs
    still drive the old control, since they run with the new controls off.
  - ☑ Sidebar edit filter (`components/sidebar/edit-navigation-menu/modal.gjs`). A static
    `DSelect` at the call site that can't be emptied, because "All" is its empty state, and
    named "Show".
    The system specs still drive the old control through the modal's page object.
- ☐ **DMenu:** the 10 `DropdownSelectBox` subclasses, user deletion, reviewable bundled actions,
  category and tag admin dropdowns, bulk-select bookmarks, and the admin "New bot" button
  (`admin/components/admin-new-bot-button.gjs`, added on `main` in #45212 and found 2026-11-24).
  Callbacks registered on their `modifySelectKit` identifiers keep running. (composer-actions is
  excluded; it is replaced independently by `composer-actions-new`.)
- ☐ **Value pickers built on `DMenu`** (audited 2026-11-11, core and bundled plugins). Their
  trigger shows the current value and their rows choose among values, so the guideline points
  them at `DSelect`. Each one is decided on its own, and one we keep on `DMenu` is checked off
  with the reason. Already tracked elsewhere: the access control permission menu and the DSA
  rule field (PHASE-3), notification tracking (the open decision in `ROLLOUT.md`), and
  `DMultiSelect` (PHASE-1).
  - Core:
    - ☐ Revision visibility (`components/modal/history/visibility-menu.gjs`). Its rows leave
      out the current value, and it ends with "Delete revision" after a divider when the
      viewer can delete. Paused 2026-11-25: every pick saves at once, as a notification level
      does, so it is decided with the notification-level family in `ROLLOUT.md`.
    - ☐ Pinned options (`components/pinned-options.gjs`).
    - ☑ Color mode (`components/interface-color-selector.gjs`). A static `DSelect` that can't be
      emptied, named "Color mode", showing only the current mode's icon, with a check on the
      current one. It is named by the picked mode's label; the old name read "[missing %{mode}
      value]" until a mode was picked. In the sidebar footer and the header it takes the flat
      look of the buttons beside it. It keeps its identifier, so the `-trigger` and `-content`
      classes and the trigger's `-expanded` state still match. Customer themes that style the
      old rows as `.interface-color-selector-content .btn` need a migration note before the flag
      defaults on.
    - ☐ Language switcher (`components/language-switcher.gjs`).
    - ☑ Nested replies sort (`components/nested/sort-selector.gjs`). A static `DSelect` named
      by the visible "Sort by" label and styled as the flat button it replaces. The system
      specs still drive the old menu through the nested view's page object.
    - ☑ Emoji skin tone (`components/emoji-picker/diversity-menu.gjs`). A static `DSelect` that
      can't be emptied, named "Skin tone", showing the clap in the current tone. The rows show
      each tone's clap and its name, from the tone strings translated since 2017 but unused until
      now; the old control read "clap:t3". "No skin tone" is stored as 1, the store's default,
      rather than `null`. On a phone the list opens as a sheet over the picker's own modal.
      Escape inside it used to close the emoji picker too, because every open float closed on
      the same Escape; float-kit now closes only the newest one, which also makes the chat
      sidebar's filter and sort submenus close one level at a time. The old rows' classes
      (`.emoji-picker__diversity-menu`, `.emoji-picker__diversity-item`, `data-level`) are gone,
      which matters to themes and to tests that click them.
    - ☑ Design wizard body and heading fonts (`components/design-wizard/fonts-section.gjs`). Two
      required `DSelectFont` typeaheads (`@clearMode="never"` and `@ariaRequired`) named by their
      captions. The wizard's fonts are keyed by `key` and listed popular first, so the recipe gained
      `@valueField` and `@sortByName`. The panel renders outside the wizard, so `DSelect` gained
      `@contentClass` to give it the wizard's colors and stacking.
    - ☐ Messages inbox (`components/user-nav/messages-dropdown.gjs`). Its rows navigate.
    - ☐ Mobile navigation dropdown (`components/navigation-bar.gjs`). Its rows navigate, and
      the `extra-nav-item` outlet renders after them.
    - ☑ Filter controls sort (`ui-kit/d-filter-controls.gts`). A static `DSelect` named "Sort by",
      with the sort icon, and only the icon below `sm`. Only the admin Upcoming changes page passes
      sort options today. An icon-only static trigger now says its value, and `@resettableTracked`
      no longer writes on read, which crashed a select whose value a modifier had read.
    - ☑ Composer toolbar popup menus (`components/toolbar-popup-menu-options.gjs`), decided
      2026-11-27. The component draws every toolbar button with a `popupMenu`, commands included
      (the "+" options menu), and customer plugins add their own.
      - ☑ Post language (`instance-initializers/post-language-selector.js`). A toolbar
        `popupMenu` may now declare `value`, the name of the option it holds; such a menu is
        drawn as a static `DSelect` (`components/toolbar-popup-select.gjs`), and the others stay
        menus. It is named "Post language" and says the post's language (the old button said
        only "Post language"), shows the language code beside its icon, lists the languages under
        "This post is in…" with a check on the current one, and "Not set" is an ordinary option.
        It keeps the toolbar's look and arrow-key order: the toolbar's roving helper now stops on
        a combobox. Opening it still runs the button's action, so plugins listening for
        `d-editor:toolbar-button-clicked` hear it. The system spec drives the old menu.
      - ☑ Text sizes and Lists stay on `DMenu`. Their rows are formatting commands on the text at
        the cursor, shown with their shortcuts, and the list rows toggle (picking the current
        list type removes it), so they aren't value pickers. Their rows don't say which one is
        active; that is a separate fix (`menuitemradio` with `aria-checked`).
    - ☐ FormKit's `menu` control (`form-kit/components/fk/control/menu.gjs`). Only the
      styleguide uses it.
    - ☑ Admin dashboard date range (`admin/components/dashboard/date-range.gjs`). Stays on
      `DMenu`: its panel is a small form that ends with Cancel and Apply buttons, so nothing is
      picked until Apply, and a listbox that commits on each pick doesn't fit it.
    - ☐ Grid pickers: `ui-kit/d-icon-grid-picker` and the emoji picker in value mode
      (`components/emoji-picker/index.gjs`). A grid is not a listbox, so these may stay.
  - Plugins:
    - ☐ chat: the channel list filter and sort submenus (`chat-channel-list-filter-menu.gjs`,
      `chat-channel-list-sort-choice.gjs`), a channel's notification level
      (`chat-channel-sidebar-context-notification-submenu.gjs`) and the search sort
      (`chat-search.gjs`).
      - ☑ Search sort. A static `DSelect` that can't be emptied, named "Sort by", showing the
        current sort with the filter controls' sort icon, and a check on the current one. The old
        button was named only by the current sort, "Relevance". No spec or theme targets the old
        menu, so it takes a BEM class, `chat-search__sort`.
    - ☑ discourse-ai: the gist toggle (`ai-gist-toggle.gjs`) and the agent list layout
      (`ai-agent-list-editor.gjs`).
      - ☑ Gist toggle. A static `DSelect` that can't be emptied, named "Layout", showing only the
        current layout's icon, with a check on the current one. It keeps the
        `topic-list-layout-trigger` class that themes hide it by. A third-party theme hides it with
        the old float-kit trigger classes too, so its author needs a migration note before the flag
        defaults on.
      - ☑ Agent list layout. The same pattern, offered only on medium and wider screens as before.
        It opens at `bottom-end`: as the row's last control, the default placement had no room and
        flipped above, as the old menu did. No other repository targets the old menu, so it takes a
        BEM class, `ai-agent-list-editor__layout`.
    - ☑ discourse-events: the "Going" menu (`discourse-post-event/status.gjs`). Stays on
      `DComboButton` and `DMenu`. Its arrow half picks a scope (this event, or this and all
      following), then "Leave event" after a divider. On desktop it is the second half of a split
      button, and `DComboButton` only takes a `DMenu` there. Split buttons elsewhere (eBay,
      Carbon, MUI, shadcn) open a menu from the arrow half, with the choices as radio items, never
      a combobox. No other `DComboButton` caller holds a value, so a select half would have one
      user. The rows don't say which scope is set; see "radio items in a menu" below.
    - ☑ poll: a ranked-choice option's rank (`poll-option-ranked-choice-dropdown.gjs`). A static
      `DSelect` that can't be emptied, named by its option's text, styled as the flat button it
      replaces. The trigger shows the number; the list marks both ends with the existing priority
      strings. Rows are list items without a tab stop of their own. Rows are now keyed by option id
      (#46941), so focus stays on the option just ranked.
    - ☐ live: the call submenus for devices, noise suppression, camera and layout
      (`live/call-submenu.gjs`).
    - ☑ discourse-workflows: the reference picker (`variable/reference-property-picker.gjs`). A
      single `DSelectList` in the menu the pill opens, opening on the current property, with the
      properties sorted by name. Any pick closes it through `@onSelect`, a re-pick included.
      "Edit code" stays below the list. Closing returns focus to the editor with the pill still
      selected, and the editor is named by its field's label.
    - ☑ discourse-workflows: the "Attributes" menu of a collection item
      (`configurators/fixed-collection.gjs`). A static multi `DSelect` with the caption
      "Attributes" and a count (`@maxVisibleChips={{0}}`), placed before the attribute inputs it
      controls. Attributes a field always shows for its type are locked. `@onSelect` shows an
      attribute's input, and `@onDeselect` hides it and resets its value.
  - Mixed, to decide (value rows beside commands): the bookmark menu's reminder times, boards'
    add-from-topic column menu, the rich editor's table menu (an alignment group among
    commands), chat's channel list menu and live's audio and video menus (commands that open
    the value submenus above), the debug and admin dashboard checkbox panels, and the site
    traffic filter pills (they remove values but can't add any).
  - Trailing action options: three of these pickers end with a destructive action after a
    divider (the permission menu, revision visibility and "Going"). The action stays an option
    in the list, reached with the arrow keys and counted with the others, so a `:footer` button
    is ruled out. An option with `position: "end"` and `divider: "before"` sits there, so the
    other two can move the same way. "Going" stays on `DMenu` (see above).
- ☐ `registerTopicFooterDropdown` gains an opt-in key.
- ☐ Customer ports for the live patches on direct `DropdownSelectBox` invocations (caret icons
  and hidden titles).

### Wave 4: generic value selects and native selects

- ☐ `ComboBox` and `MultiSelect` with static content, period chooser, notifications filter.
- ☐ **FormKit `select` and `DNativeSelect`:** decide between new control types and a switch inside
  the shared control; preserve value types, empty values, disabled state, labels and errors, form
  participation, and query parameters (`d-filter-controls`). Deprecate `DNativeSelect`.

## To investigate

- ☐ **A held value that hasn't loaded may hand Enter to row one (unverified).** A single
  `typeahead` or desktop `static` DSelect enters with `selected-or-first`
  (`variant-presenter.ts`, `entryFocus`). With a `@load` source that pages, the held value may be
  on a page that hasn't loaded. The cursor would then fall back to the first row, and Enter on
  opening would replace the held value with it. Not reproduced yet. Try a paged `@load` whose held
  value sits past the first page (given through `@valueRecords`), open it, and check which row is
  active and what Enter emits. If confirmed, entering with `selected-or-none` whenever a value is
  held should fix it, which is what DSelectList already does. Pin it with a failing test first.

- ☐ **Size the panel from its rows instead of a hand-picked floor.** A panel is as wide as its
  trigger (`@matchTriggerWidth`), lifted to `--d-select-menu-min-width` (12em by default). That
  floor doesn't know the rows, so a narrow trigger wraps long labels, and a selected row wraps
  sooner because its label turns bold. Seven callers set their own floor (14em, 16em or 20em), and
  the workflows attributes menu is the eighth. CSS alone can't size from the rows: a virtualized
  list positions its rows absolutely, so `max-content` doesn't see them. Look for a way to measure
  the widest label once per option set, in its selected weight, and size the panel from it,
  capped by the viewport.

- ☐ **Radio items in a menu (decide later; outside the select work).** `DDropdownMenu` is a
  plain list of buttons inside a `DMenu` whose content is a `dialog`. A menu that marks a current
  choice can only show it with a class and an icon, so screen readers don't hear it: "Going", the
  editor's Text sizes and Lists, and the navigation dropdowns. React Aria lets each section of a
  `Menu` hold its own selection beside plain action items, and shadcn uses
  `DropdownMenuRadioGroup`. Giving `DDropdownMenu` menu semantics (`menu`, `menuitem`,
  `menuitemradio` with `aria-checked`, `separator`, arrow keys) would fix them all. It is a
  ui-kit change that needs its own plan.

## Exit criteria

- Every family above has joined, on the primitive the guideline picks.
- FormKit and native consumers pass in both modes, including mobile.
