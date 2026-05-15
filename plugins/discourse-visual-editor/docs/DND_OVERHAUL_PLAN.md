# Drag-and-drop overhaul: single drop indicator + operation feedback

## Context

The editor currently runs **two independent drop-target systems** that both paint visual feedback during a drag:

1. **Per-block sibling/inside strip zones** — physical 4px `.visual-editor-drop-zone` DOM elements around every block (`block-chrome.gjs:768-953`), each its own `dDragAndDropTarget` modifier instance. They eat real layout space all the time, and an active one flashes a tinted band.
2. **Grid-level capture-phase dragover handler** — `GridOverlay` installs `addEventListener("dragover", ..., true)` on the grid `<div>` (`grid-overlay.gjs:297-301`) and writes a `dropPreview` descriptor consumed by an absolute-positioned overlay element (`.visual-editor-grid-drop-overlay`, with `--rect-swap`/`--rect-replace`/`--rect-move`/`--line-column`/`--line-row` variants).

Both fire at grid cell edges. The chrome's `--before` strip lights up at the same time the grid overlay paints a `--line-column`. The outline panel rows can flash too (`outline-panel.gjs:638-642`), and empty grid cells run their own `+` affordance independently. Users see **multiple simultaneous drop indicators** with no idea which one represents the real drop.

There is also **no operation feedback** — the drop preview is colored rectangles/lines but never carries text. Users can't tell whether a drop will insert, move, replace, or swap until after they let go. The "Drop here to add inside" copy is inconsistent (shown sometimes, not others) and the inside-drop strip is "janky" per the user.

Goal: a single drop indicator at any moment, painted by ONE authority per drag, that says exactly what operation will happen to which target. Invalid targets simply don't light up.

## Approach

### 1. Single drop-preview authority

One **drop coordinator** owns the active descriptor for an entire drag. There is exactly one `<DropPreview>` element painted on screen during a drag — never two.

**File**: new `assets/javascripts/discourse/components/editor/drop-preview.gjs`. Renders an absolutely-positioned overlay (`<div class="visual-editor-drop-preview">`) anchored to the canvas root. Listens to a single tracked `activeDropPreview` on the `visualEditor` service:

```js
{
  kind: "insert" | "replace" | "swap" | "shift" | "inside" | "occupy",
  geometry: { top, left, width, height }, // absolute viewport-relative
  variant: "valid" | "invalid",           // drives color
  label: "Move Heading after Paragraph",  // operation feedback (i18n key + interpolation)
}
```

Mount once at the editor shell level (`editor/shell.gjs`); a single render path means impossible-to-have-two-overlays-by-construction.

**Move the responsibility out of `GridOverlay`** — its `dropPreview` becomes a *contributor* to the service-level coordinator, not a parallel renderer. `GridOverlay.overlayStyle` + the `--rect-*`/`--line-*` overlay element get deleted.

### 2. Replace per-block strip zones with edge detection

Today every block has three 4px `<div>` drop-zone children (`--before`, `--after`, `--inside`). They take layout space, they each have their own modifier instance, and they each paint independently.

Replace them with **a single dragover handler at each layout-container boundary** (chrome of stack/row/grid containers). The handler:

1. On `dragover`, reads the cursor's position relative to the container's bounding box.
2. Projects the cursor onto the container's children — for stack/row layouts, finds the nearest gap (between child N and N+1, or before the first / after the last).
3. Computes the operation:
   - cursor in the upper third of a child → INSERT before
   - cursor in the lower third → INSERT after
   - cursor in the middle third, and the child IS a container → INSIDE
   - cursor in the middle third, and the child is a slot → REPLACE
   - cursor in the middle third, and the child is a regular block → no overlay (no valid landing)
4. Validates the drop via `canDropAt` / `canInsertBlockAt` — if invalid, descriptor is `{variant: "invalid"}` (or null, if we don't want to flash anything for invalid).
5. Writes `visualEditor.activeDropPreview = descriptor`.

`drop` handler: read the captured descriptor, dispatch to `insertBlock` / `moveBlock` / `fillSlot` / `moveBlockIntoSlot` accordingly.

This deletes the per-element `.visual-editor-drop-zone` DOM elements entirely. The container's chrome owns ONE dragover listener; the overlay paints ONE rectangle/line.

### 3. Grid drop-site selection unified

`GridOverlay`'s existing math (`_descriptorFromCursor`, `_computeZone`, `_cellDescriptorForZone`, `_slotDescriptorForZone`) is correct — it stays. The change: instead of writing to its own `dropPreview` and painting its own overlay element, it writes to `visualEditor.activeDropPreview` in the same shape the container handlers use. One source of truth.

The `+` empty-cell placeholders in `GridOverlay` are PERSISTENT affordances (not drag previews) — they stay rendered, but **during a drag they fade to low opacity** so the unified overlay is unambiguously the drop indicator. CSS-only — `body.visual-editor-dragging .visual-editor-grid-cell { opacity: 0.3 }`.

### 4. Operation-feedback label

The descriptor's `label` field is rendered inside the overlay as a small badge — top-left corner, 12px font, contrasting background, never overlapping the geometry it labels.

**Label computation** (the coordinator builds it):

| Source kind | Operation | Label |
|---|---|---|
| `ve-palette-block` | `insert` (before/after) | `"Add {BlockName} here"` |
| `ve-palette-block` | `inside` | `"Add {BlockName} inside {ContainerName}"` |
| `ve-palette-block` | `replace` (ve:slot) | `"Fill slot with {BlockName}"` |
| `ve-palette-block` | `occupy` (grid cell) | `"Add {BlockName} to cell"` |
| `ve-block` | `insert` | `"Move {BlockName} here"` |
| `ve-block` | `inside` | `"Move {BlockName} inside {ContainerName}"` |
| `ve-block` | `replace` (ve:slot) | `"Move {BlockName} into slot"` |
| `ve-block` | `swap` (grid) | `"Swap with {TargetBlockName}"` |
| `ve-block` | `shift` (grid edge) | `"Insert before / after — neighbors shift"` |
| any | `invalid` | overlay hidden, OR `"Can't drop here"` with red variant |

Block display names come from `getBlockDisplayMetadata(component).displayName` (already used by the palette + outline).

### 5. Validation gates the visual feedback

Today: invalid targets still light up; the drop just silently fails. New rule: **the overlay only renders when the drop would succeed**.

Predicates already exist (`canDropOnThisBlock`, `canInsertBlockAt`, `canDropAt`). Move their results into the descriptor:

- The coordinator computes the operation tentatively (where would it land?).
- Then validates via the existing predicates.
- If invalid → set `activeDropPreview = null` (no overlay) OR `variant: "invalid"` (red-tinted overlay with a "Can't drop here" label). I'd default to `null` so the user just doesn't see a target — much quieter UX. We can re-introduce the red variant later if "no feedback at all" turns out to be confusing.

### 6. Drag-session lifecycle

A single drag has a clear lifecycle the coordinator owns:

- `dragstart` on a source → `visualEditor.startDrag(source)` (existing). Service sets `body.visual-editor-dragging` class + `activeDropPreview = null`.
- `dragover` on any registered scope (container chrome, grid overlay) → scope handler reads cursor, computes descriptor, writes `activeDropPreview`. Capture-phase listener at the canvas root catches "off-canvas" dragover and clears the descriptor.
- `drop` on the originating scope's drop modifier → read `_lastDropPreview` (sticky descriptor, captured the tick before clear), dispatch the resulting operation.
- `dragend` / `dragleave-canvas` → clear `activeDropPreview`, remove `body.visual-editor-dragging`.

The chrome's existing `dDragAndDropTarget` modifiers are replaced by ONE container-level handler per layout. The outline panel keeps its own simple "drop here" pattern (it's a sidebar, doesn't compete with the canvas).

### 7. Outline panel drag stays as-is

The outline's drop indicators are sidebar tree rows — they don't compete visually with the canvas because they're on a different surface. Leave that path alone; it can keep its built-in `dDragAndDropTarget` highlight.

## Files to add

- `plugins/discourse-visual-editor/assets/javascripts/discourse/components/editor/drop-preview.gjs` — single overlay element + label, mounted at shell level. Reads `visualEditor.activeDropPreview`.
- `plugins/discourse-visual-editor/assets/javascripts/discourse/modifiers/container-drop-target.js` — replaces the per-block strip modifiers. Attached to each layout's container element (the `<div>` that holds the children list). One handler per container; ONE descriptor at a time.

## Files to modify

- `services/visual-editor.js` — add `@tracked activeDropPreview`, `setActiveDropPreview(descriptor)`, `clearActiveDropPreview()`. Add `describeDropOperation(source, target, position)` returning `{kind, label, validity}` so chrome/overlay/outline call into a single labelling helper.
- `components/editor/block-chrome.gjs` — delete the `--before` / `--after` / `--inside` drop-zone children and their template branches (lines ~768-953). Replace with a single `containerDropTarget` modifier on the chrome wrapping a container block. Stack-mode chromes only need this; leaf-block chromes drop the target entirely (their parent container handles it). `canDropOnThisBlock` / `canDropOnSlot` / `applyDrop` consolidate into `applyContainerDrop({descriptor, source})`.
- `components/editor/grid-overlay.gjs` — keep the math (`_descriptorFromCursor`, `_computeZone`, etc.); delete `dropPreview` tracked state, `overlayStyle`, `overlayVariantClass`, and the `.visual-editor-grid-drop-overlay` element. Write into `visualEditor.activeDropPreview` instead.
- `components/editor/shell.gjs` — mount `<DropPreview />` at the canvas root.
- `assets/stylesheets/visual-editor.scss` — delete `.visual-editor-drop-zone` rules; add `.visual-editor-drop-preview` (the single overlay) with one valid + one invalid variant; add `body.visual-editor-dragging .visual-editor-grid-cell { opacity: 0.3 }`.
- `config/locales/client.en.yml` — add `canvas.drop_preview.*` keys for the operation labels.

## Existing primitives reused

- **Cursor → cell math** (grid): `_readGridTracks`, `_cursorToCell`, `_computeZone` in `grid-overlay.gjs` — stays untouched, only its output destination changes.
- **Drop predicates**: `canDropOnThisBlock` (`block-chrome.gjs:657`), `canInsertBlockAt` (`visual-editor.js:2165`), `canDropAt` — combine into one helper `validateDrop(source, target, position)` on the service.
- **Drop dispatch**: `moveBlock`, `insertBlock`, `fillSlot`, `moveBlockIntoSlot`, `swapSlotPlacements`, `insertBlockAtCell` — keep, called from the unified drop dispatcher.
- **Block display names**: `getBlockDisplayMetadata(component).displayName` — for label interpolation.
- **`body.visual-editor-active`** class — sister class `body.visual-editor-dragging` follows the same pattern for drag-only CSS gating.

## Verification

After `bin/rails server` is up and a homepage has a registered layout with multiple blocks:

1. `bin/lint --fix --recent` — clean.
2. `bin/qunit plugins/discourse-visual-editor/test/javascripts/unit/lib/mutate-layout-test.gjs` — existing tests green.
3. Drag a palette block over a stack-mode container with three children. Confirm:
   - Exactly ONE drop indicator at any cursor position (no double-highlight near boundaries).
   - Label reads "Add Heading here" (or whichever block).
   - Moving the cursor between gaps glides the indicator without flashing two.
4. Drag a canvas block over a grid-mode layout. Confirm:
   - Exactly ONE indicator (single rect, single line — not a chrome strip + grid overlay).
   - Label changes between "Move X here", "Swap with Y", "Insert before — neighbors shift" depending on cursor position.
5. Drag a palette block over a `ve:slot`. Confirm label says "Fill slot with X" and only the slot lights up.
6. Drag a palette block of type `ve:heading` onto an outlet with `deniedOutlets: ['sidebar-blocks']` set. Confirm NO overlay appears anywhere over that outlet (validation gates the visual).
7. Drop. Confirm the operation matches the label that was visible before release.
8. Visually: empty grid cells fade to 30% opacity during drag (they're persistent affordances, not drag previews).
9. Outline-panel drag still works as today (separate surface, unchanged).

## Out of scope (defer)

- Animated overlay transitions (the current grid overlay glides; the new one can match later).
- Keyboard-driven drop preview (today's drag is mouse-only; keyboard reordering is a separate feature).
- A "Can't drop here" red variant — start with `null` (no overlay) for invalid, revisit if users miss the feedback.
- Refactoring the outline panel drop pattern — leave as-is.
