// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { getBlockDisplayMetadata } from "discourse/lib/blocks/-internals/display-metadata";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";
// `grid-math` is in the universal bundle (its `parsePlacement` is
// called by the live-page `ve-layout.gjs`); this component is
// admin-only. Cross-bundle imports use absolute addon paths.
import {
  computeOccupation,
  computeShiftPlan,
  parsePlacement,
  unoccupiedCells,
} from "discourse/plugins/discourse-visual-editor/discourse/lib/grid-math";
import { entryKey } from "../../lib/mutate-layout";
import EmptyCellPlaceholder from "./empty-cell-placeholder";

/**
 * Edit-mode affordances for a selected `ve:layout` in grid mode.
 *
 * Rather than render a separate grid that sits ON TOP of the layout
 * (which fought alignment endlessly because the two grids resolve row
 * heights independently), this component teleports its edit-mode DOM
 * — empty-cell placeholders, slot tiles, and the drop overlay — INTO
 * the layout's own grid `<div>` via `{{#in-element}}`. Cells, slots,
 * and tiles all become direct children of the same CSS Grid container,
 * so their grid placements snap to the same tracks by construction.
 *
 * What gets rendered (inside the layout's grid):
 *  - For every empty (column, row), a `<div>` with a `+` button that
 *    opens a compact block picker.
 *  - For every slot, an invisible tile `<div>` at the slot's grid
 *    coordinates. The tile body is the drag-to-move surface; a corner
 *    handle drags to resize; hover reveals a delete `×`.
 *  - A resize ghost `<div>` repositioned by `gridTileDrag` to preview
 *    the proposed cell rectangle during a resize gesture.
 *  - A single drop-preview overlay `<div>` that the component
 *    repositions during a drag-and-drop to mark where the block will
 *    land (rectangle over a cell for "land here / swap" actions; thin
 *    line in a grid gap for "insert between cells" actions).
 *
 * Drop-preview overlay vs. drag ghost: deliberately separate elements
 * even though both live inside the same grid. The resize ghost is
 * driven by `gridTileDrag` (pointer-events) via CSS grid placement;
 * the drop overlay is driven by HTML5 DnD events via absolute pixel
 * positions so it can render a thin line midway in a grid gap.
 * Sharing one element would force one path to teach the other its
 * style protocol.
 *
 * Args:
 *  - `@gridKey` — the layout block's composite key (lets us locate
 *    the entry in the resolved layout via the editor service).
 *  - `@outletName` — the outlet the layout lives in.
 */
export default class GridOverlay extends Component {
  @service visualEditor;
  @service blocks;
  @service dragAndDrop;

  /**
   * Active drop-preview descriptor — drives the overlay element's
   * shape, position and tint. Slot wrappers in `BlockChrome` set this
   * via `visualEditor.setDropPreview(gridKey, descriptor)`; empty-cell
   * handlers set it directly via `setDropPreview(descriptor)` since
   * they live in this component.
   *
   * Shape (null = overlay hidden):
   *  - `{kind: "rect", column: {start, end}, row: {start, end},
   *     variant: "swap"|"replace"|"move"}`
   *  - `{kind: "line-column", line, row: {start, end},
   *     variant: "insert"}` — vertical line at column line `line`,
   *     bounded vertically by `row` (defaults to full grid height).
   *  - `{kind: "line-row", line, column: {start, end},
   *     variant: "insert"}` — horizontal line at row line `line`,
   *     bounded horizontally by `column` (defaults to full width).
   *
   * @type {Object|null}
   */
  @tracked dropPreview = null;
  // Emits CSS custom properties rather than concrete `grid-column` /
  // `grid-row` so a parent `@container` rule (the auto-collapse
  // override in `visual-editor-chrome.scss`) can override the cell's
  // placement when the layout collapses to one column. Inline
  // `style="grid-column: ..."` would win over any stylesheet rule;
  // the custom-property hand-off lets the stylesheet take precedence
  // when needed without `!important`. Same pattern `ve-layout`'s
  // `cellStyle` uses for `.ve-layout__cell`.
  //
  // `order` is also set so that when the `@container` collapse rewrites
  // every cell to `grid-row: auto`, auto-placement walks the children
  // in (row, col) reading order — empty cells interleave naturally with
  // slot chromes in the stacked view. Harmless in the expanded grid
  // because explicit `grid-column` / `grid-row` placements take
  // priority over `order` there.
  cellStyle = (cell) =>
    trustHTML(
      `--ve-grid-cell-column: ${cell.column} / ${cell.column + 1}; ` +
        `--ve-grid-cell-row: ${cell.row} / ${cell.row + 1}; ` +
        `order: ${(cell.row - 1) * 1000 + (cell.column - 1)};`
    );

  isPickingCell = (cell) =>
    this._pickingCell?.column === cell.column &&
    this._pickingCell?.row === cell.row;

  /**
   * Accept palette drops AND existing-block drops. Both route through
   * `applyCellDrop` below, branching on `source.kind`.
   */
  acceptedDropKinds = ["ve-block", "ve-palette-block"];
  /**
   * Cell currently in "pick a block" mode. `null` when no picker is
   * open. Stored here (rather than per-cell state) so clicking another
   * `+` swaps the picker over instead of opening a second one.
   *
   * @type {{column: number, row: number}|null}
   */
  @tracked _pickingCell = null;

  /**
   * The layout's grid `<div>`, located on insert via the marker's
   * sibling lookup. `{{#in-element}}` mounts the cells / tiles / ghost
   * into this element so they share the layout's CSS Grid context.
   * Tracked so the conditional `{{#if this._gridElement}}` re-renders
   * once the ref is captured.
   */
  @tracked _gridElement = null;

  /** Resize ghost element ref, captured on its own insert. */
  _ghostElement = null;

  /** Drop-preview overlay element ref, captured on its own insert. */
  _overlayElement = null;

  /**
   * Sticky drop-preview descriptor captured at the most recent
   * dragover so drop dispatch can branch on the SAME zone the user
   * was visually targeting. `dropPreview` itself gets cleared during
   * cleanup (drag-leave, drop) before the drop handler reads it, so
   * we mirror it here for the brief read-after-clear window.
   *
   * @type {Object|null}
   */
  _lastDropPreview = null;

  /**
   * Lazily-installed dragover / dragleave handlers attached to the
   * grid container itself (not to per-cell children). Captured here
   * so `willDestroy` can detach them.
   */
  _gridDragOverHandler = null;
  _gridDragLeaveHandler = null;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this._gridElement && this._gridDragOverHandler) {
      this._gridElement.removeEventListener(
        "dragover",
        this._gridDragOverHandler,
        true
      );
    }
    if (this._gridElement && this._gridDragLeaveHandler) {
      this._gridElement.removeEventListener(
        "dragleave",
        this._gridDragLeaveHandler,
        true
      );
    }
    this.visualEditor.unregisterGridOverlay(this.args.gridKey, this);
  }

  get gridEntry() {
    // Open a tracked dep on structuralVersion so re-renders fire on
    // every layout mutation (slot insertions / removals / placement
    // changes).
    // eslint-disable-next-line no-unused-vars
    const _v = this.visualEditor.structuralVersion;
    return this.visualEditor._findEntryAndOutletSync(this.args.gridKey)?.entry;
  }

  get columns() {
    return Number(this.gridEntry?.args?.columns ?? 6);
  }

  get rows() {
    return Number(this.gridEntry?.args?.rows ?? 2);
  }

  get slots() {
    return this.gridEntry?.children ?? [];
  }

  get emptyCells() {
    const occupied = computeOccupation(this.slots, this.columns, this.rows);
    return unoccupiedCells(occupied, this.columns, this.rows);
  }

  /**
   * `true` when the layout is currently below its `autoCollapse`
   * width threshold — i.e. the universal `@container` rule in
   * `visual-editor.scss` has fired and each cell now spans all
   * columns via `grid-column: 1 / -1`. The grid container itself
   * keeps `display: grid` and its original `grid-template-columns`
   * (per the CSS spec, `@container` queries style descendants, not
   * the container element itself), so the only direct signal is the
   * container's measured width vs the SCSS thresholds.
   *
   * Drives the dispatch to the DOM-element hit-test / overlay paths
   * in `_descriptorFromCursor` and `_computeOverlayGeometry`: track
   * math doesn't fit a layout whose cells all span 1 / -1, so we
   * hand off to element lookups instead.
   *
   * The thresholds (40rem / 15rem) are duplicated from
   * `visual-editor.scss` because there's no clean way to read a
   * @container's max-width from JS; if either constant changes,
   * update both sides.
   *
   * Returns `false` when an ancestor carries `.--force-expanded`
   * (the editor-only override restores per-author placements so the
   * track-math path is correct).
   */
  get isCollapsed() {
    const gridEl = this._gridElement;
    if (!gridEl) {
      return false;
    }
    if (gridEl.closest(".--force-expanded")) {
      return false;
    }
    const autoCollapse = this.gridEntry?.args?.autoCollapse ?? "default";
    if (autoCollapse === "never") {
      return false;
    }
    const remPx =
      parseFloat(getComputedStyle(document.documentElement).fontSize) || 16;
    const thresholdRem = autoCollapse === "compact" ? 15 : 40;
    return gridEl.getBoundingClientRect().width < thresholdRem * remPx;
  }

  /**
   * Compact palette for the cell picker — same data as the main
   * palette but filtered to user-pickable blocks and sorted by
   * category then displayName.
   */
  @cached
  get palette() {
    return this.blocks
      .listBlocksWithMetadata()
      .map(({ name, component }) => {
        const display = getBlockDisplayMetadata(component) ?? {};
        return {
          name,
          displayName: display.displayName,
          icon: display.icon,
          category: display.category ?? "Misc",
          paletteHidden: display.paletteHidden === true,
          previewArgs: display.previewArgs ?? {},
        };
      })
      .filter((row) => !row.paletteHidden)
      .sort(
        (a, b) =>
          a.category.localeCompare(b.category) ||
          a.displayName.localeCompare(b.displayName)
      );
  }

  /**
   * Inline style + class for the overlay element. Empty descriptor =
   * hidden (`opacity: 0`); rect descriptor = absolutely positioned
   * over the cell rectangle; line descriptor = a thin strip drawn in
   * the grid gap. CSS transitions on `top/left/width/height` glide
   * the overlay between targets as the descriptor mutates.
   */
  get overlayStyle() {
    const d = this.dropPreview;
    if (!d || !this._gridElement) {
      return trustHTML("opacity: 0;");
    }
    const geometry = this._computeOverlayGeometry(d);
    if (!geometry) {
      return trustHTML("opacity: 0;");
    }
    return trustHTML(
      `opacity: 1; ` +
        `top: ${geometry.top}px; left: ${geometry.left}px; ` +
        `width: ${geometry.width}px; height: ${geometry.height}px;`
    );
  }

  get overlayVariantClass() {
    const d = this.dropPreview;
    if (!d) {
      return "";
    }
    if (d.kind === "rect") {
      return `--rect-${d.variant ?? "swap"}`;
    }
    if (d.kind === "line-column") {
      return "--line-column";
    }
    if (d.kind === "line-row") {
      return "--line-row";
    }
    return "";
  }

  /**
   * Mutator for the overlay state. Called from sibling slot wrappers
   * (via `visualEditor.setDropPreview`) and from this component's own
   * empty-cell handlers. Records the descriptor in two places:
   * `dropPreview` drives the rendered overlay via reactivity;
   * `_lastDropPreview` survives the cleanup that fires just before
   * `applyCellDrop` / `applySlotDrop` reads it.
   */
  @action
  setDropPreview(descriptor) {
    this.dropPreview = descriptor;
    if (descriptor) {
      this._lastDropPreview = descriptor;
    }
    // Mirror to the unified `activeDropPreview` so the single
    // `<DropPreview>` overlay (mounted at the editor shell) paints
    // the grid's drop indicator. Drop DISPATCH still goes through
    // this component's own `applyCellDrop` / `applySlotDrop` —
    // those read `_lastDropPreview` above and resolve to the right
    // grid action (swap / replace / shift / occupy). The unified
    // service-level dispatch is bypassed for grid drops because
    // the grid's math doesn't fit the generic insertBlock /
    // moveBlock contract.
    this._mirrorToActivePreview(descriptor);
  }

  /**
   * Translates an internal grid descriptor (`{kind: "rect"|
   * "line-column"|"line-row", column, row, variant}`) into the
   * unified viewport-coord descriptor the shell-mounted
   * `<DropPreview>` paints. Skipped silently when geometry can't
   * be resolved (e.g. before the grid element is captured).
   *
   * @param {Object|null} descriptor
   */
  _mirrorToActivePreview(descriptor) {
    if (!descriptor || !this._gridElement) {
      this.visualEditor.setActiveDropPreview(null);
      return;
    }
    const gridRel = this._computeOverlayGeometry(descriptor);
    if (!gridRel) {
      this.visualEditor.setActiveDropPreview(null);
      return;
    }
    const gridRect = this._gridElement.getBoundingClientRect();
    const geometry = {
      top: gridRect.top + gridRel.top,
      left: gridRect.left + gridRel.left,
      width: gridRel.width,
      height: gridRel.height,
    };
    const source = this.visualEditor.dragSource;
    this.visualEditor.setActiveDropPreview({
      geometry,
      kind: this._unifiedKindFor(descriptor),
      // Translate the descriptor's `_invalid` sentinel (set by
      // `_descriptorFromCursor` when the underlying operation would
      // be rejected) into the unified `validity` flag the overlay's
      // red styling keys off of.
      validity: descriptor._invalid ? "invalid" : "valid",
      label: this._labelFor(descriptor, source),
      // No `dispatch` — grid drops dispatch via this component's
      // own onDrop handlers (`applyCellDrop` / `applySlotDrop`),
      // which read from `this._lastDropPreview`.
    });
  }

  _unifiedKindFor(descriptor) {
    if (descriptor.kind === "rect") {
      if (descriptor.variant === "swap") {
        return "swap";
      }
      if (descriptor.variant === "replace") {
        return "replace";
      }
      return "occupy";
    }
    return descriptor.variant === "insert" ? "shift" : "insert";
  }

  _labelFor(descriptor, source) {
    if (!source) {
      return "";
    }
    const sourceName = this._sourceDisplayName(source);
    const kind = this._unifiedKindFor(descriptor);
    if (kind === "swap") {
      return i18n("visual_editor.canvas.drop_preview.swap", {
        name: sourceName,
      });
    }
    if (kind === "replace") {
      return source.kind === "ve-palette-block"
        ? i18n("visual_editor.canvas.drop_preview.fill_slot", {
            name: sourceName,
          })
        : i18n("visual_editor.canvas.drop_preview.move_into_slot", {
            name: sourceName,
          });
    }
    if (kind === "shift") {
      return i18n("visual_editor.canvas.drop_preview.shift", {
        name: sourceName,
      });
    }
    // occupy / fallback
    return source.kind === "ve-palette-block"
      ? i18n("visual_editor.canvas.drop_preview.add_to_cell", {
          name: sourceName,
        })
      : i18n("visual_editor.canvas.drop_preview.move_to_cell", {
          name: sourceName,
        });
  }

  _sourceDisplayName(source) {
    if (source.kind === "ve-palette-block") {
      return (
        this.visualEditor._lookupBlockDisplayName(source.data.blockName) ||
        source.data.blockName ||
        "block"
      );
    }
    if (source.kind === "ve-block") {
      const located = this.visualEditor._findEntryAndOutletSync(
        source.data.blockKey
      );
      if (located?.entry) {
        return (
          this.visualEditor._lookupBlockDisplayName(located.entry.block) ||
          "block"
        );
      }
    }
    return "block";
  }

  @action
  registerSelf() {
    this.visualEditor.registerGridOverlay(this.args.gridKey, this);
  }

  @action
  captureGridElement(element) {
    // The marker `<span>` is a sibling of the layout's grid div within
    // the chrome wrapper. Walk up to chrome and find the layout div so
    // `{{#in-element}}` below mounts cells / overlay as direct grid
    // children.
    const gridEl = element.parentElement?.querySelector(".ve-layout--grid");
    this._gridElement = gridEl;
    if (!gridEl) {
      return;
    }
    // Drive the overlay descriptor from a single grid-level dragover
    // listener so the overlay appears as soon as the cursor enters the
    // grid — not only when it's over a specific cell or slot. The
    // cursor's pixel position resolves to a cell coordinate via the
    // grid's resolved track sizes, then to a zone within that cell. A
    // line variant in the gap between two cells stays positioned in
    // that gap even when the cursor is mid-traverse between cells.
    //
    // Capture phase: the per-cell `dDragAndDropTarget` modifier calls
    // `event.stopPropagation()` in its own dragover handler, which
    // would suppress this listener if we attached on the bubble phase.
    // Using `capture: true` ensures we observe the event before the
    // modifier sees (and stops) it.
    this._gridDragOverHandler = (e) => this._handleGridDragOver(e);
    this._gridDragLeaveHandler = (e) => this._handleGridDragLeave(e);
    gridEl.addEventListener("dragover", this._gridDragOverHandler, true);
    gridEl.addEventListener("dragleave", this._gridDragLeaveHandler, true);
  }

  @action
  captureGhost(element) {
    this._ghostElement = element;
  }

  @action
  captureOverlay(element) {
    this._overlayElement = element;
  }

  /**
   * Handles a drop onto an empty cell. The shape of the drop differs by
   * `source.kind`:
   *  - `"ve-palette-block"` → insert a fresh block at the cell.
   *  - `"ve-block"` → move an existing block to the cell (via
   *     `moveBlockToCell`, which preserves slot identity for same-grid
   *     drags).
   */
  /**
   * Drop handler for empty cells. The descriptor — set by the
   * grid-level dragover listener — carries everything the dispatch
   * needs (target cell coords / line / row / column / variant). The
   * `cell` arg is the drop-target's own coords, used only as a
   * fallback when the descriptor is missing.
   */
  @action
  applyCellDrop(cell, { source }) {
    const descriptor = this._lastDropPreview;
    this.setDropPreview(null);
    this._lastDropPreview = null;
    this._dispatchDrop({ descriptor, source, fallbackCell: cell });
    this.visualEditor.endDrag?.();
  }

  /**
   * Drop handler for slot wrappers in `BlockChrome`. Same dispatch
   * path as `applyCellDrop` — the descriptor is the source of truth;
   * the slot's own cell is used only as a fallback.
   */
  @action
  applySlotDrop({ source, fallbackCell }) {
    const descriptor = this._lastDropPreview;
    this.setDropPreview(null);
    this._lastDropPreview = null;
    this._dispatchDrop({ descriptor, source, fallbackCell });
    this.visualEditor.endDrag?.();
  }

  /**
   * Single dispatch path shared between cell and slot drops — the
   * descriptor knows what variant / line / cell is being targeted,
   * so the source element type doesn't matter for routing.
   */
  _dispatchDrop({ descriptor, source, fallbackCell }) {
    if (descriptor?.kind === "line-column") {
      this._dispatchInsertWithShift({
        dropCell: {
          column: descriptor.line,
          row: descriptor.row?.start ?? fallbackCell?.row ?? 1,
        },
        direction: "left",
        source,
      });
      return;
    }
    if (descriptor?.kind === "line-row") {
      this._dispatchInsertWithShift({
        dropCell: {
          column: descriptor.column?.start ?? fallbackCell?.column ?? 1,
          row: descriptor.line,
        },
        direction: "up",
        source,
      });
      return;
    }
    if (descriptor?.kind === "rect" && descriptor.variant === "swap") {
      this.visualEditor.swapSlotPlacements({
        slotKeyA: this._slotKeyAtPlacement(descriptor),
        slotKeyB: source?.data?.blockKey,
      });
      return;
    }
    if (descriptor?.kind === "rect" && descriptor.variant === "replace") {
      this.visualEditor.replaceSlot({
        targetSlotKey: this._slotKeyAtPlacement(descriptor),
        sourceSlotKey: source?.data?.blockKey,
      });
      return;
    }
    // Default / variant === "move": land on the descriptor's column/row
    // start (or the drop element's own cell as fallback).
    const column = descriptor?.column?.start ?? fallbackCell?.column ?? null;
    const row = descriptor?.row?.start ?? fallbackCell?.row ?? null;
    if (column == null || row == null) {
      return;
    }
    if (source?.kind === "ve-palette-block") {
      this.visualEditor.insertBlockAtCell({
        gridKey: this.args.gridKey,
        blockName: source.data.blockName,
        defaultArgs: source.data.defaultArgs,
        column,
        row,
      });
    } else if (source?.kind === "ve-block") {
      this.visualEditor.moveBlockToCell({
        gridKey: this.args.gridKey,
        sourceKey: source.data.blockKey,
        column,
        row,
      });
    }
  }

  /**
   * Finds the slot whose placement matches the rect-descriptor's
   * `column`/`row` (the slot being swapped / replaced). Returns its
   * block key, or `null` if no slot covers that rectangle.
   */
  _slotKeyAtPlacement(descriptor) {
    if (!descriptor?.column || !descriptor?.row) {
      return null;
    }
    const slot = this._slotAtCell({
      column: descriptor.column.start,
      row: descriptor.row.start,
    });
    return slot ? entryKey(slot) : null;
  }

  /**
   * Grid-level dragover handler. Fires on every mouse move while a
   * compatible drag is in flight and the cursor is anywhere inside
   * the grid (gaps between cells included). Computes a descriptor
   * from the cursor's pixel position via the grid's resolved tracks,
   * so the overlay tracks the cursor continuously rather than
   * waiting for it to enter a child element.
   */
  _handleGridDragOver(event) {
    const source = this.dragAndDrop.currentDrag;
    if (
      !source ||
      (source.kind !== "ve-block" && source.kind !== "ve-palette-block")
    ) {
      return;
    }
    // Must call preventDefault on dragover so the subsequent `drop`
    // event fires (HTML5 DnD spec). The per-empty-cell
    // `dDragAndDropTarget` modifiers do this for the cells they own,
    // but grid-positioned leaves (occupied cells like A / B in a
    // 6×2 grid) rely solely on this capture-phase handler to
    // qualify their drop event.
    event.preventDefault();
    const descriptor = this._descriptorFromCursor(event, source);
    this.setDropPreview(descriptor);
  }

  /**
   * Clears the overlay when the cursor leaves the grid entirely.
   * `dragleave` ALSO fires when the cursor crosses from the grid
   * into a child; suppress that case by checking whether the
   * `relatedTarget` (the element the cursor moved INTO) is still
   * inside the grid.
   */
  _handleGridDragLeave(event) {
    const rt = event.relatedTarget;
    if (rt && this._gridElement?.contains(rt)) {
      return;
    }
    this.setDropPreview(null);
  }

  /**
   * Translates the cursor's pixel coordinates within the grid into a
   * drop-preview descriptor. Algorithm:
   *  1. Read resolved track widths / heights / gaps via
   *     `getComputedStyle`.
   *  2. Map cursor x → column-index, cursor y → row-index by walking
   *     the track positions cumulatively.
   *  3. Compute the cell's pixel bounds and the cursor's position
   *     INSIDE that bounding box → 5-zone hit test (center / left /
   *     right / up / down).
   *  4. If the cell is occupied by a slot, produce a slot-level
   *     descriptor (swap / replace / insert). Otherwise produce an
   *     empty-cell descriptor (move / insert).
   *
   * Returns `null` (overlay hidden) when the cursor is outside the
   * resolved track range or the source can't drop on the resolved
   * target (e.g. palette block onto an occupied slot's center).
   */
  _descriptorFromCursor(event, source) {
    // The source can never be dropped onto itself or into any of its
    // own descendants — that would create a cycle. Hide the overlay
    // entirely when the cursor is hovering THIS grid and the source
    // either IS this grid's layout or an ancestor of it.
    const sourceKey =
      source?.kind === "ve-block" ? source.data?.blockKey : null;
    if (sourceKey && this._sourceCoversTarget(sourceKey, this.args.gridKey)) {
      return null;
    }

    if (this.isCollapsed) {
      return this._descriptorFromCursorCollapsed(event, source, sourceKey);
    }

    const tracks = this._readGridTracks();
    if (!tracks) {
      return null;
    }
    const gridRect = this._gridElement.getBoundingClientRect();
    const x = event.clientX - gridRect.left;
    const y = event.clientY - gridRect.top;

    const cell = this._cursorToCell(x, y, tracks);
    if (!cell) {
      return null;
    }
    const bounds = this._cellBounds(cell, tracks);
    const zone = this._computeZone(
      x - bounds.left,
      y - bounds.top,
      bounds.width,
      bounds.height
    );

    const slot = this._slotAtCell(cell);
    let descriptor;
    if (slot) {
      // Same check at the slot level — never preview a drop onto the
      // source slot itself or any slot nested inside the source.
      const slotKey = entryKey(slot);
      if (sourceKey && this._sourceCoversTarget(sourceKey, slotKey)) {
        return null;
      }
      descriptor = this._slotDescriptorForZone({
        slot,
        zone,
        shift: event.shiftKey,
        source,
      });
    } else {
      descriptor = this._cellDescriptorForZone(cell, zone);
    }
    if (!descriptor) {
      return null;
    }
    // Real-time validity gate. Some descriptor shapes (line-column /
    // line-row inserts that need to cascade existing slots out of the
    // way) only succeed when the shift plan fits the grid. If it
    // doesn't, mark the descriptor with the `_invalid` sentinel so
    // the mirrored unified preview paints in danger tones — the
    // author sees what they intended but knows the drop will be
    // rejected. Without this, the overlay reads as a normal valid
    // target and the drop silently fails on release.
    //
    // We use a separate sentinel field (`_invalid`) rather than
    // overwriting `variant` because the descriptor's `variant`
    // already carries the operation kind (`insert` / `swap` /
    // `replace` / `move`) that `_dispatchDrop` switches on.
    if (!this._canExecuteDescriptor(descriptor, source)) {
      return { ...descriptor, _invalid: true };
    }
    return descriptor;
  }

  /**
   * Collapsed-view variant of `_descriptorFromCursor`. The track-math
   * path can't run here: a multi-column logical grid that's rendering
   * as one column has `colWidths.length === 1`, so cursor X always
   * resolves to `column 1` and `_trackStart(col=3, widths)` returns
   * NaN.
   *
   * Instead we hit-test by DOM element. `elementFromPoint` finds the
   * visible slot chrome or empty-cell placeholder under the cursor;
   * its `data-ve-block-key` / `data-col` / `data-row` map back to
   * logical coordinates; cursor Y within the element's bounding rect
   * resolves a 3-zone hit test (up / center / down — left and right
   * don't have meaningful semantics in a vertical stack).
   *
   * Output is exactly the same descriptor shape as the track-math
   * path — `_dispatchDrop` and `_computeOverlayGeometry` (via its own
   * collapsed branch) consume it the same way.
   */
  _descriptorFromCursorCollapsed(event, source, sourceKey) {
    const el = document.elementFromPoint(event.clientX, event.clientY);
    if (!el || !this._gridElement.contains(el)) {
      return null;
    }

    // Empty cell placeholder — check this first. Empty cells are
    // teleported directly into the grid and never contain blocks
    // with `data-ve-block-key`, so a hit on one is unambiguous.
    const emptyEl = el.closest(".visual-editor-grid-cell");
    if (emptyEl && this._gridElement.contains(emptyEl)) {
      const col = parseInt(emptyEl.getAttribute("data-col"), 10);
      const row = parseInt(emptyEl.getAttribute("data-row"), 10);
      if (Number.isNaN(col) || Number.isNaN(row)) {
        return null;
      }
      const rect = emptyEl.getBoundingClientRect();
      const zone = this._computeZoneCollapsed(
        event.clientY - rect.top,
        rect.height
      );
      const base = this._cellDescriptorForZone({ column: col, row }, zone);
      return this._finishCollapsedDescriptor(
        this._attachCollapsedHit(base, rect, zone),
        source
      );
    }

    // Slot — walk up `[data-ve-block-key]` ancestors until we find
    // one that's a DIRECT child of this grid's layout entry. The
    // cursor may be over a nested block inside a container slot
    // (e.g. a paragraph inside a card-shaped slot), in which case
    // `closest` returns the innermost chrome whose key isn't in
    // `this.slots`; we want the outer slot's chrome instead.
    let candidate = el.closest("[data-ve-block-key]");
    while (candidate && this._gridElement.contains(candidate)) {
      const blockKey = candidate.getAttribute("data-ve-block-key");
      const slot = this.slots.find((s) => entryKey(s) === blockKey);
      if (slot) {
        if (sourceKey && this._sourceCoversTarget(sourceKey, blockKey)) {
          return null;
        }
        const rect = candidate.getBoundingClientRect();
        const zone = this._computeZoneCollapsed(
          event.clientY - rect.top,
          rect.height
        );
        const base = this._slotDescriptorForZone({
          slot,
          zone,
          shift: event.shiftKey,
          source,
        });
        return this._finishCollapsedDescriptor(
          this._attachCollapsedHit(base, rect, zone),
          source
        );
      }
      candidate = candidate.parentElement?.closest("[data-ve-block-key]");
    }

    return null;
  }

  /**
   * Stamps the collapsed-view hit-test result onto the base descriptor
   * so `_computeOverlayGeometryCollapsed` can paint against the actual
   * element the cursor was over, without round-tripping through
   * logical (col, row) → DOM lookups. The latter fails for auto-placed
   * slots (whose `placement.start` is null) and for any case where
   * `_slotAtCell` can't resolve the cell back to an element.
   *
   * The viewport-coord rect is captured at hit-test time; the
   * mirroring step converts to grid-relative the same way the
   * track-math path does, so the rest of the pipeline stays uniform.
   */
  _attachCollapsedHit(descriptor, rect, zone) {
    if (!descriptor) {
      return null;
    }
    return {
      ...descriptor,
      _collapsedRect: {
        top: rect.top,
        left: rect.left,
        width: rect.width,
        height: rect.height,
      },
      _collapsedZone: zone,
    };
  }

  /**
   * Three-zone Y-axis hit test for the collapsed view. Left / right
   * don't carry semantics in a vertical stack — only top (insert
   * above) / center (swap-or-move-into) / bottom (insert below) do.
   */
  _computeZoneCollapsed(y, h) {
    const edge = 0.25;
    if (h <= 0) {
      return "center";
    }
    const fromTop = y / h;
    if (fromTop < edge) {
      return "up";
    }
    if (fromTop > 1 - edge) {
      return "down";
    }
    return "center";
  }

  /**
   * Applies the same validity gate the track-math path uses so the
   * mirrored overlay can paint in danger tones for impossible drops
   * (e.g. shift-insert that doesn't fit the grid).
   */
  _finishCollapsedDescriptor(descriptor, source) {
    if (!descriptor) {
      return null;
    }
    if (!this._canExecuteDescriptor(descriptor, source)) {
      return { ...descriptor, _invalid: true };
    }
    return descriptor;
  }

  /**
   * Returns `true` when `_dispatchDrop` would produce a real change
   * for `descriptor` + `source`. Shift-insert descriptors call into
   * `computeShiftPlan` to see whether the cascade fits within the
   * grid; swap / replace / occupy descriptors always succeed at this
   * stage (cycle / self-drop checks already happened upstream in
   * `_descriptorFromCursor` via `_sourceCoversTarget`).
   */
  _canExecuteDescriptor(descriptor, source) {
    if (!descriptor) {
      return false;
    }
    if (descriptor.kind === "line-column" || descriptor.kind === "line-row") {
      const dropCell =
        descriptor.kind === "line-column"
          ? {
              column: descriptor.line,
              row: descriptor.row?.start ?? 1,
            }
          : {
              column: descriptor.column?.start ?? 1,
              row: descriptor.line,
            };
      const direction = descriptor.kind === "line-column" ? "left" : "up";
      const sourceKey =
        source?.kind === "ve-block" ? source.data?.blockKey : null;
      // Only same-grid sources free a cell; cross-grid arrivals don't.
      let sourceInGrid = null;
      if (sourceKey) {
        const located = this.visualEditor._findEntryAndOutletSync?.(sourceKey);
        if (located?.outletName === this._outletName(this.args.gridKey)) {
          for (const slot of this.slots) {
            if (entryKey(slot) === sourceKey) {
              sourceInGrid = sourceKey;
              break;
            }
          }
        }
      }
      const plan = computeShiftPlan({
        slots: this.slots,
        sourceKey: sourceInGrid,
        dropCell,
        direction,
        gridDims: { columns: this.columns, rows: this.rows },
      });
      return plan != null;
    }
    return true;
  }

  _outletName(blockKey) {
    return this.visualEditor._findEntryAndOutletSync?.(blockKey)?.outletName;
  }

  /**
   * Returns `true` if `targetKey` IS `sourceKey` or is one of its
   * descendants. Used to block the drop preview on illegal targets
   * (a block dropped into itself or its own subtree would form a
   * cycle in the layout tree).
   */
  _sourceCoversTarget(sourceKey, targetKey) {
    if (!sourceKey || !targetKey) {
      return false;
    }
    if (sourceKey === targetKey) {
      return true;
    }
    return this.visualEditor._isAncestorOf(sourceKey, targetKey);
  }

  /**
   * Maps a pixel position (relative to the grid's top-left) to a
   * 1-indexed `(column, row)` cell. Pixels falling in a column gap
   * snap to the column whose nearest edge is closer (i.e. the gap
   * is split halfway). Returns `null` when the position falls outside
   * the grid's resolved track range.
   */
  _cursorToCell(x, y, tracks) {
    const col = this._findTrackIndex(x, tracks.colWidths, tracks.colGap);
    const row = this._findTrackIndex(y, tracks.rowHeights, tracks.rowGap);
    if (col == null || row == null) {
      return null;
    }
    return { column: col, row };
  }

  /**
   * 1-indexed track lookup. Walks the cumulative track positions
   * (track width + gap, ad infinitum) and returns the index of the
   * track whose right edge — including half the trailing gap — the
   * cursor hasn't passed yet. Past the last track, returns the last
   * track's index.
   */
  _findTrackIndex(pos, sizes, gap) {
    if (pos < 0) {
      return null;
    }
    let acc = 0;
    for (let i = 0; i < sizes.length; i++) {
      const trackEnd = acc + sizes[i];
      if (pos <= trackEnd + gap / 2) {
        return i + 1;
      }
      acc = trackEnd + gap;
    }
    return sizes.length;
  }

  /**
   * Pixel rectangle for a `(column, row)` cell, computed from the
   * grid's resolved tracks. Used to compute the cursor's position
   * within the cell for zone detection.
   */
  _cellBounds(cell, tracks) {
    const left = this._trackStart(cell.column, tracks.colWidths, tracks.colGap);
    const right = this._trackEnd(
      cell.column + 1,
      tracks.colWidths,
      tracks.colGap
    );
    const top = this._trackStart(cell.row, tracks.rowHeights, tracks.rowGap);
    const bottom = this._trackEnd(
      cell.row + 1,
      tracks.rowHeights,
      tracks.rowGap
    );
    return {
      left,
      top,
      width: right - left,
      height: bottom - top,
    };
  }

  /**
   * Finds the slot whose placement covers `(cell.column, cell.row)`.
   * Auto-placed slots (no explicit column / row) are ignored — for
   * descriptor purposes we treat their cells as empty.
   */
  _slotAtCell(cell) {
    for (const slot of this.slots) {
      const placement = parsePlacement(slot.containerArgs);
      if (placement.column.start == null || placement.row.start == null) {
        continue;
      }
      if (
        cell.column >= placement.column.start &&
        cell.column < placement.column.end &&
        cell.row >= placement.row.start &&
        cell.row < placement.row.end
      ) {
        return slot;
      }
    }
    return null;
  }

  /**
   * Slot-level descriptor for a given zone. Center maps to a rect
   * (swap / replace if Shift, or null when the source is a palette
   * block — palette blocks can't land on an occupied cell's center).
   * Edges map to thin lines in the gap on the slot's outer perimeter.
   */
  _slotDescriptorForZone({ slot, zone, shift, source }) {
    const placement = parsePlacement(slot.containerArgs);
    const slotKey = entryKey(slot);
    if (zone === "center") {
      if (source?.kind !== "ve-block") {
        return null;
      }
      if (source.data?.blockKey === slotKey) {
        return null;
      }
      return {
        kind: "rect",
        column: placement.column,
        row: placement.row,
        variant: shift ? "replace" : "swap",
      };
    }
    if (zone === "left") {
      return {
        kind: "line-column",
        line: placement.column.start,
        row: placement.row,
        variant: "insert",
      };
    }
    if (zone === "right") {
      return {
        kind: "line-column",
        line: placement.column.end,
        row: placement.row,
        variant: "insert",
      };
    }
    if (zone === "up") {
      return {
        kind: "line-row",
        line: placement.row.start,
        column: placement.column,
        variant: "insert",
      };
    }
    if (zone === "down") {
      return {
        kind: "line-row",
        line: placement.row.end,
        column: placement.column,
        variant: "insert",
      };
    }
    return null;
  }

  /**
   * Translates a 5-zone hit-test result for an empty cell into a
   * drop-preview descriptor. Edge zones produce line descriptors with
   * line numbers that are SHARED with the adjacent slot / cell —
   * "right of cell C" and "left of cell C+1" both resolve to the same
   * column line, so the overlay snaps to the same position from either
   * side.
   */
  _cellDescriptorForZone(cell, zone) {
    if (zone === "left") {
      return {
        kind: "line-column",
        line: cell.column,
        row: { start: cell.row, end: cell.row + 1 },
        variant: "insert",
      };
    }
    if (zone === "right") {
      return {
        kind: "line-column",
        line: cell.column + 1,
        row: { start: cell.row, end: cell.row + 1 },
        variant: "insert",
      };
    }
    if (zone === "up") {
      return {
        kind: "line-row",
        line: cell.row,
        column: { start: cell.column, end: cell.column + 1 },
        variant: "insert",
      };
    }
    if (zone === "down") {
      return {
        kind: "line-row",
        line: cell.row + 1,
        column: { start: cell.column, end: cell.column + 1 },
        variant: "insert",
      };
    }
    return {
      kind: "rect",
      column: { start: cell.column, end: cell.column + 1 },
      row: { start: cell.row, end: cell.row + 1 },
      variant: "move",
    };
  }

  _dispatchInsertWithShift({ dropCell, direction, source }) {
    this.visualEditor.insertWithShift({
      gridKey: this.args.gridKey,
      dropCell,
      direction,
      sourceKey: source?.kind === "ve-block" ? source.data?.blockKey : null,
      paletteBlockName:
        source?.kind === "ve-palette-block" ? source.data?.blockName : null,
      paletteDefaultArgs:
        source?.kind === "ve-palette-block" ? source.data?.defaultArgs : null,
    });
  }

  /**
   * Five-zone hit test inside a cell. Returns `"center"` for the
   * inner 60% rect, otherwise one of `"left"`/`"right"`/`"up"`/
   * `"down"` (outer 20% bands). Corners resolve to whichever edge
   * the cursor is RELATIVELY closer to — `x/w` vs `y/h` rather than
   * absolute pixels — so a hover on the left edge of a tall narrow
   * cell stays "left" instead of biasing toward "up"/"down" near
   * corners.
   */
  _computeZone(x, y, w, h) {
    const edge = 0.2;
    const fromLeft = x / w;
    const fromRight = (w - x) / w;
    const fromTop = y / h;
    const fromBottom = (h - y) / h;
    const minFromEdge = Math.min(fromLeft, fromRight, fromTop, fromBottom);

    if (minFromEdge > edge) {
      return "center";
    }
    if (minFromEdge === fromLeft) {
      return "left";
    }
    if (minFromEdge === fromRight) {
      return "right";
    }
    if (minFromEdge === fromTop) {
      return "up";
    }
    return "down";
  }

  /**
   * Computes the absolute pixel rectangle for the overlay based on
   * the descriptor. Reads resolved track widths from
   * `getComputedStyle(grid).gridTemplateColumns/Rows` — the browser
   * resolves any `fr` / template expressions to pixel widths there,
   * so the math doesn't have to handle the source template.
   *
   * Returns `null` when the descriptor references lines outside the
   * resolved track range — caller hides the overlay in that case.
   *
   * @returns {{top: number, left: number, width: number, height: number}|null}
   */
  _computeOverlayGeometry(descriptor) {
    if (this.isCollapsed) {
      return this._computeOverlayGeometryCollapsed(descriptor);
    }
    const tracks = this._readGridTracks();
    if (!tracks) {
      return null;
    }
    const { colWidths, rowHeights, colGap, rowGap } = tracks;
    const stroke = 4;

    if (descriptor.kind === "rect") {
      const colStart = descriptor.column?.start;
      const colEnd = descriptor.column?.end;
      const rowStart = descriptor.row?.start;
      const rowEnd = descriptor.row?.end;
      if (
        colStart == null ||
        colEnd == null ||
        rowStart == null ||
        rowEnd == null
      ) {
        return null;
      }
      const left = this._trackStart(colStart, colWidths, colGap);
      const right = this._trackEnd(colEnd, colWidths, colGap);
      const top = this._trackStart(rowStart, rowHeights, rowGap);
      const bottom = this._trackEnd(rowEnd, rowHeights, rowGap);
      return {
        left,
        top,
        width: Math.max(0, right - left),
        height: Math.max(0, bottom - top),
      };
    }

    if (descriptor.kind === "line-column") {
      const lineX = this._lineMidpoint(descriptor.line, colWidths, colGap);
      const rowStart = descriptor.row?.start ?? 1;
      const rowEnd = descriptor.row?.end ?? rowHeights.length + 1;
      const top = this._trackStart(rowStart, rowHeights, rowGap);
      const bottom = this._trackEnd(rowEnd, rowHeights, rowGap);
      return {
        left: lineX - stroke / 2,
        top,
        width: stroke,
        height: Math.max(0, bottom - top),
      };
    }

    if (descriptor.kind === "line-row") {
      const lineY = this._lineMidpoint(descriptor.line, rowHeights, rowGap);
      const colStart = descriptor.column?.start ?? 1;
      const colEnd = descriptor.column?.end ?? colWidths.length + 1;
      const left = this._trackStart(colStart, colWidths, colGap);
      const right = this._trackEnd(colEnd, colWidths, colGap);
      return {
        left,
        top: lineY - stroke / 2,
        width: Math.max(0, right - left),
        height: stroke,
      };
    }

    return null;
  }

  /**
   * Collapsed-view variant of `_computeOverlayGeometry`. Looks up the
   * destination DOM element (slot chrome or empty-cell placeholder)
   * by its logical (column, row) coordinates and uses its bounding
   * rect — translated into grid-relative coords — to paint the
   * overlay over what the author actually sees in the stacked view.
   * Skips the track-math entirely.
   *
   * Line descriptors paint along the target element's TOP edge when
   * `descriptor.line === row.start` (the cell at `line` is the target;
   * insert ABOVE it) or BOTTOM edge when `descriptor.line === row + 1`
   * (the cell at `line - 1` is the target; insert BELOW it).
   * `line-column` descriptors don't come out of the collapsed hit-test
   * — left/right zones aren't emitted — so they're handled as a
   * fallback only.
   */
  _computeOverlayGeometryCollapsed(descriptor) {
    if (!this._gridElement) {
      return null;
    }
    const rect = descriptor._collapsedRect;
    if (!rect) {
      return null;
    }
    const gridRect = this._gridElement.getBoundingClientRect();
    const stroke = 4;

    if (descriptor.kind === "rect") {
      return {
        left: rect.left - gridRect.left,
        top: rect.top - gridRect.top,
        width: rect.width,
        height: rect.height,
      };
    }

    if (descriptor.kind === "line-row") {
      // The hit test produces "up" → line on top edge, "down" → line
      // on bottom edge. Use the zone we stamped onto the descriptor
      // rather than the abstract `descriptor.line` index, so the
      // overlay tracks the same element the cursor was over.
      const y =
        descriptor._collapsedZone === "down"
          ? rect.top + rect.height
          : rect.top;
      return {
        left: rect.left - gridRect.left,
        top: y - gridRect.top - stroke / 2,
        width: rect.width,
        height: stroke,
      };
    }

    // line-column descriptors aren't emitted by the collapsed hit
    // test — left/right zones don't make sense in a vertical stack.
    return null;
  }

  /**
   * Reads resolved track widths + gaps from the grid element's
   * computed style. Returns `null` if the grid element isn't ready
   * yet (overlay just rendered, hasn't captured the ref).
   */
  _readGridTracks() {
    const gridEl = this._gridElement;
    if (!gridEl) {
      return null;
    }
    const cs = getComputedStyle(gridEl);
    const colWidths = (cs.gridTemplateColumns || "")
      .split(" ")
      .map((s) => parseFloat(s))
      .filter((v) => !Number.isNaN(v));
    const rowHeights = (cs.gridTemplateRows || "")
      .split(" ")
      .map((s) => parseFloat(s))
      .filter((v) => !Number.isNaN(v));
    if (!colWidths.length || !rowHeights.length) {
      return null;
    }
    const colGap = parseFloat(cs.columnGap) || 0;
    const rowGap = parseFloat(cs.rowGap) || 0;
    return { colWidths, rowHeights, colGap, rowGap };
  }

  /**
   * Pixel offset of the LEFT edge of an item starting at grid line
   * `line`. With `gap` between tracks, line K (K > 1) is preceded by
   * (K-1) tracks and (K-1) gaps in the layout, so the item's left
   * edge falls after both. Line 1 is the grid's origin (0).
   */
  _trackStart(line, sizes, gap) {
    if (line <= 1) {
      return 0;
    }
    if (line > sizes.length + 1) {
      return this._trackEnd(sizes.length + 1, sizes, gap);
    }
    let sum = 0;
    for (let i = 0; i < line - 1; i++) {
      sum += sizes[i];
    }
    return sum + (line - 1) * gap;
  }

  /**
   * Pixel offset of the RIGHT edge of an item ending at grid line
   * `line`. The trailing gap after the last track of a span is NOT
   * included — only the (line-2) gaps interspersed BETWEEN the spanned
   * tracks contribute.
   */
  _trackEnd(line, sizes, gap) {
    if (line <= 1) {
      return 0;
    }
    if (line > sizes.length + 1) {
      let total = 0;
      for (let i = 0; i < sizes.length; i++) {
        total += sizes[i];
      }
      return total + (sizes.length - 1) * gap;
    }
    let sum = 0;
    for (let i = 0; i < line - 1; i++) {
      sum += sizes[i];
    }
    return sum + (line - 2) * gap;
  }

  /**
   * Pixel position of grid line `line` for line-variant overlays.
   * Lines 1 and N+1 are flush with the grid's edges (no gap to be
   * "midway in"); interior lines sit at the centre of the gap between
   * the adjacent tracks. The overlay's stroke is then drawn straddling
   * this position.
   */
  _lineMidpoint(line, sizes, gap) {
    if (line <= 1) {
      return 0;
    }
    if (line >= sizes.length + 1) {
      return this._trackEnd(sizes.length + 1, sizes, gap);
    }
    return this._trackEnd(line, sizes, gap) + gap / 2;
  }

  @action
  openPicker(cell, event) {
    event.preventDefault();
    event.stopPropagation();
    this._pickingCell = cell;
  }

  @action
  closePicker(event) {
    event?.preventDefault?.();
    this._pickingCell = null;
  }

  @action
  pickBlock(blockEntry, event) {
    event.preventDefault();
    event.stopPropagation();
    const cell = this._pickingCell;
    if (!cell) {
      return;
    }
    this.visualEditor.insertBlockAtCell({
      gridKey: this.args.gridKey,
      blockName: blockEntry.name,
      defaultArgs: { ...blockEntry.previewArgs },
      column: cell.column,
      row: cell.row,
    });
    this._pickingCell = null;
  }

  <template>
    {{! Marker — invisible. On insert, finds the sibling layout grid
      div so we can teleport the edit-mode DOM into the same CSS Grid
      container the slots already live in. Also registers this
      component on the editor service so sibling slot wrappers can
      route drop-preview updates back here. }}
    <span
      class="visual-editor-grid-edit-marker"
      aria-hidden="true"
      {{didInsert this.captureGridElement}}
      {{didInsert this.registerSelf}}
    ></span>

    {{#if this._gridElement}}
      {{! `insertBefore=null` appends without wiping the slots already
        rendered inside the grid div. }}
      {{#in-element this._gridElement insertBefore=null}}
        {{#each this.emptyCells as |cell|}}
          <div
            class="visual-editor-grid-cell"
            style={{this.cellStyle cell}}
            data-col={{cell.column}}
            data-row={{cell.row}}
            {{dDragAndDropTarget
              accepts=this.acceptedDropKinds
              onDrop=(fn this.applyCellDrop cell)
            }}
          >
            <EmptyCellPlaceholder
              @palette={{this.palette}}
              @isOpen={{this.isPickingCell cell}}
              @onOpen={{fn this.openPicker cell}}
              @onClose={{this.closePicker}}
              @onPick={{this.pickBlock}}
            />
          </div>
        {{/each}}

        <div
          class="visual-editor-grid-ghost"
          aria-hidden="true"
          {{didInsert this.captureGhost}}
        ></div>
        {{! The grid-local drop overlay element is removed — the
          shell-mounted `<DropPreview>` is now the single drop
          indicator; this component mirrors its descriptor into
          `visualEditor.activeDropPreview` via `setDropPreview`. }}
      {{/in-element}}
    {{/if}}
  </template>
}
