# COMING NEXT — Block toolbar overflow (the badge in tight space)

## Problem

Each block's floating "badge" is the `wireframe-block-toolbar` — a rounded tab
anchored above the chrome's top-left corner (`position: absolute; bottom: 100%`).
It carries two things:

1. **Handle / identity** (always rendered): grip icon + block display name +
   optional ordinal chip ("Tab 2"). Also the drag source.
2. **Action buttons** (only when `@isSelected`): move back/forward, duplicate
   (+ count combo), optional detach, optional force-expand, inline-format
   (bold / italic / link), delete.

The bar is `display: inline-flex` with **no width cap**, so on a narrow block
(a thin grid cell, a narrow column) it overflows its block. The selected bar
with 6–9 buttons is far wider than the block; even the idle handle's name can
exceed a thin column. It currently just spills rightward over the canvas and
neighbouring chrome.

## Goal — three width tiers

Driven by the block's own width. The action row folds into a single hamburger
**all at once** (not button-by-button):

| Tier         | Trigger                                   | Handle                         | Actions                       |
|--------------|-------------------------------------------|--------------------------------|-------------------------------|
| **Full**     | full inline bar fits the block width      | grip + name + ordinal          | all buttons inline            |
| **Narrow**   | full bar doesn't fit, but handle+☰ does   | grip + name + ordinal          | single ☰ holding **all** actions |
| **Narrower** | even handle+☰ doesn't fit                 | grip (drag source) + ☰; name → `title` | single ☰ holding all actions  |

Unselected / hover state has no action buttons, so only the handle's identity
tiering applies (name truncates with ellipsis, then drops to the tooltip).

## Design decisions

### 1. One action-descriptor source (DRY)

The inline buttons and the hamburger-menu items must render from **one**
source, or they will drift. Today each button is hand-coded in the template.
Refactor the action set into a getter returning an ordered list of descriptors:

```js
// shape (illustrative)
{ id, icon, label, action, disabled?, active?, danger?, group? }
```

Render that list two ways:
- **Full tier** → inline `DButton`s (current look).
- **Narrow / Narrower** → `DDropdownMenu` items inside the hamburger.

The Duplicate-with-count combo becomes, in the menu, a "Duplicate" item plus
the ×2/×3/×5/×10 presets and the custom field (a submenu or a grouped block).
Inline-format buttons (bold/italic/link) only enter the list when
`showInlineFormat` is true; they collapse with everything else.

### 2. Tier detection — measured, not fixed breakpoints

A fixed container-query breakpoint (the existing `@container` pattern) is
tempting and consistent with the codebase, **but** the bar's natural width
varies a lot by block type and state (3 buttons for a plain block, ~9 for a
selected image block in an in-place text session). A single px/rem breakpoint
either clips the busy bar or over-collapses the sparse one.

Use a **measured tier** instead:

- A small modifier on the toolbar observes the **chrome's content-box width**
  (`available`) via `ResizeObserver` — reuse the pattern already in
  `block-chrome.gjs` (the resize-handle observer).
- Capture two **stable thresholds**, recomputed only when the *action
  signature* changes (selection, inline-format visibility, detach/expand
  availability, image fill/reset) — **not** on every resize, to avoid
  hysteresis:
  - `fullWidth`  = natural width of the complete inline bar.
  - `compactWidth` = natural width of (grip + name + ordinal + ☰).
- Pick the tier: `available >= fullWidth` → Full;
  else `available >= compactWidth` → Narrow; else → Narrower.
- Apply via a `data-toolbar-tier="full|narrow|narrower"` attribute the SCSS
  reacts to (keeps layout decisions in CSS, state in one place).

Measuring natural widths: render the full bar (it already overflows; set
`max-width: 100%; overflow: hidden` so it never pushes layout) and read the
inner flex content's `scrollWidth` for `fullWidth`. `compactWidth` is the grip
+ name + ordinal + one button's worth for ☰ — measured from the same render.

Because thresholds change only on signature change, resize never oscillates.

### 3. Hamburger trigger

- Icon: `bars`. `DButton` styled like the other `__btn`s, opening a
  `DDropdownMenu` via the FloatKit menu service (same machinery the Duplicate
  combo already uses — `@onRegisterApi` to capture the API so picking an item
  closes it).
- New i18n key: `wireframe.canvas.toolbar.more` ("More actions").
- **Drag source survives into Narrower tier via the grip.** Today the handle
  (grip + name) is the drag source. In Narrower the name is gone; keep the grip
  icon as a standalone drag source (the `dDragAndDropSource` modifier stays on
  it) sitting next to the ☰, so reorder-by-drag stays obvious and the hamburger
  is purely a menu trigger. Decided: grip + ☰, not a draggable hamburger.

### 4. Identity / name handling

- Name span gets `max-width: 100%; overflow: hidden; text-overflow: ellipsis;
  white-space: nowrap` so it truncates gracefully in Full/Narrow before the
  tier even flips.
- In Narrower the name span is hidden; the block name moves to the handle's
  `title` (already wired via `@displayTitle` / `@displayName`).
- Ordinal chip ("Tab 2") stays in Full/Narrow, drops in Narrower.

### 5. Outlet root & composite parts

These render identity only (no structural actions): the outlet root shows the
cube icon + name + status chip; a part shows the dashed icon + name. They never
need the hamburger — only name truncation applies. The status chip should stay
visible (truncate the name around it). No tier-3 collapse for them.

### 6. URL-edit state of the bar

When editing a rich-text link, the bar swaps its actions for a URL `<input>` +
apply/remove/cancel buttons. That input needs real width and shouldn't collapse
into a menu. Treat this state as its own layout: cap the input width and let the
three buttons stay inline (the input can shrink). Out of scope to fold into the
hamburger.

## Edge cases & non-goals

- **Vertical clipping** (block at the very top of the canvas/viewport → bar
  clipped above) is a *separate* problem and **out of scope** here. Note it as a
  follow-up: flip the bar below the block when there's no room above.
- Menu closes on any action pick (reuse the `#duplicateMenu.close()` pattern).
- Move icons/labels are already orientation-aware (`isHorizontalMove`); the menu
  items reuse the same getters.
- Accessibility: `role="toolbar"` stays; the hamburger needs `aria-haspopup`
  + an `aria-label`; menu items carry their existing titles/labels.
- The just-selected flash and reveal-into-view (`block-reveal.js`) are unaffected
  — they target the chrome, not the bar.

## Implementation steps

1. **`block-toolbar.gjs`** — extract the action set into an ordered descriptor
   getter; render inline buttons (Full) or `DDropdownMenu` items (Narrow/Narrower)
   from it. Add the hamburger trigger + its menu. Read the tier from a tracked
   value fed by the measuring modifier.
2. **New lib** (e.g. `lib/toolbar-fit.js`) or a modifier — `ResizeObserver` on
   the chrome + threshold capture on signature change; emits the tier. Keep it a
   dependency-free leaf (matches the `block-reveal.js` style).
3. **`wireframe-chrome.scss`** — `max-width: 100%` on `.wireframe-block-toolbar`;
   name ellipsis rules; `[data-toolbar-tier]` rules to show/hide the name,
   ordinal, inline actions, and hamburger per tier.
4. **i18n** — `wireframe.canvas.toolbar.more`.
5. **Tests** — rendering tests that set the chrome to known widths and assert the
   resulting `data-toolbar-tier` and which controls are present. (Note: tier is
   layout-driven; the test must give the chrome a real width and let the observer
   settle — `await settled()` after sizing.)

## Files

- `admin/assets/javascripts/discourse/components/editor/block-toolbar.gjs`
- `admin/assets/javascripts/discourse/lib/toolbar-fit.js` (new)
- `assets/stylesheets/admin/wireframe-chrome.scss`
- `config/locales/client.en.yml` (the `more` key)
- `test/javascripts/...` (rendering test)
