// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { getBlockDisplayMetadata } from "discourse/lib/blocks/-internals/display-metadata";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";
import { computeOccupation, unoccupiedCells } from "../../lib/grid-math";

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
  cellStyle = (cell) =>
    trustHTML(
      `grid-column: ${cell.column} / ${cell.column + 1}; ` +
        `grid-row: ${cell.row} / ${cell.row + 1};`
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
   * Map from cell element to the per-cell `dragover` listener
   * installed on entry. The shared drag-and-drop modifier only
   * surfaces `onDragEnter`/`onDragLeave`/`onDrop`; we need
   * continuous cursor updates inside the cell to swap between
   * edge / center zones, so we install our own listener on enter
   * and remove it on leave / drop.
   */
  _cellDragOverHandlers = new WeakMap();

  willDestroy() {
    super.willDestroy(...arguments);
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
    this._gridElement =
      element.parentElement?.querySelector(".ve-layout--grid");
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
  @action
  applyCellDrop(cell, { source, element }) {
    // Capture the last descriptor BEFORE we clear it — cleanup happens
    // first so the overlay disappears immediately on drop.
    const descriptor = this._lastDropPreview;
    this._detachCellDragOverListener(element);
    this.setDropPreview(null);
    this._lastDropPreview = null;

    if (descriptor?.kind === "line-column") {
      this._dispatchInsertWithShift({
        dropCell: { column: descriptor.line, row: cell.row },
        direction: "left",
        source,
      });
    } else if (descriptor?.kind === "line-row") {
      this._dispatchInsertWithShift({
        dropCell: { column: cell.column, row: descriptor.line },
        direction: "up",
        source,
      });
    } else {
      // Default to the cell's center semantics — drop onto the cell.
      if (source?.kind === "ve-palette-block") {
        this.visualEditor.insertBlockAtCell({
          gridKey: this.args.gridKey,
          blockName: source.data.blockName,
          defaultArgs: source.data.defaultArgs,
          column: cell.column,
          row: cell.row,
        });
      } else if (source?.kind === "ve-block") {
        this.visualEditor.moveBlockToCell({
          gridKey: this.args.gridKey,
          sourceKey: source.data.blockKey,
          column: cell.column,
          row: cell.row,
        });
      }
    }
    this.visualEditor.endDrag?.();
  }

  @action
  onCellDragEnter(cell, { element, event }) {
    if (!this._cellDragOverHandlers.has(element)) {
      const handler = (e) => this._updateCellPreview(cell, e, element);
      this._cellDragOverHandlers.set(element, handler);
      element.addEventListener("dragover", handler);
    }
    this._updateCellPreview(cell, event, element);
  }

  @action
  onCellDragLeave(_cell, { element }) {
    this._detachCellDragOverListener(element);
    this.setDropPreview(null);
  }

  _detachCellDragOverListener(element) {
    const handler = this._cellDragOverHandlers.get(element);
    if (handler) {
      element.removeEventListener("dragover", handler);
      this._cellDragOverHandlers.delete(element);
    }
  }

  _updateCellPreview(cell, event, element) {
    const zone = this._computeCellDropZone(event, element);
    this.setDropPreview(this._cellDescriptorForZone(cell, zone));
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
   * Five-zone hit test inside an empty cell, matching the slot
   * wrapper's `_computeDropZone`. Returns `"center"` for the inner
   * 60% rect, otherwise one of `"left"`/`"right"`/`"up"`/`"down"`.
   * Corners resolve to the nearer edge.
   */
  _computeCellDropZone(event, element) {
    const rect = element.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    const w = rect.width;
    const h = rect.height;
    const edge = 0.2;

    const inLeft = x < w * edge;
    const inRight = x > w * (1 - edge);
    const inTop = y < h * edge;
    const inBottom = y > h * (1 - edge);

    if (inLeft && inTop) {
      return x < y ? "left" : "up";
    }
    if (inRight && inTop) {
      return w - x < y ? "right" : "up";
    }
    if (inLeft && inBottom) {
      return x < h - y ? "left" : "down";
    }
    if (inRight && inBottom) {
      return w - x < h - y ? "right" : "down";
    }
    if (inLeft) {
      return "left";
    }
    if (inRight) {
      return "right";
    }
    if (inTop) {
      return "up";
    }
    if (inBottom) {
      return "down";
    }
    return "center";
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
            {{dDragAndDropTarget
              accepts=this.acceptedDropKinds
              onDragEnter=(fn this.onCellDragEnter cell)
              onDragLeave=(fn this.onCellDragLeave cell)
              onDrop=(fn this.applyCellDrop cell)
            }}
          >
            <button
              type="button"
              class="visual-editor-grid-cell__plus"
              title={{i18n "visual_editor.canvas.grid_overlay.add_at_cell"}}
              {{on "click" (fn this.openPicker cell)}}
            >
              {{dIcon "plus"}}
            </button>
            {{#if (this.isPickingCell cell)}}
              <div class="visual-editor-grid-cell__picker">
                <div class="visual-editor-grid-cell__picker-header">
                  <span>{{i18n
                      "visual_editor.canvas.grid_overlay.pick_block"
                    }}</span>
                  <button
                    type="button"
                    class="visual-editor-grid-cell__picker-close"
                    title={{i18n "visual_editor.canvas.grid_overlay.cancel"}}
                    {{on "click" this.closePicker}}
                  >
                    {{dIcon "xmark"}}
                  </button>
                </div>
                <div class="visual-editor-grid-cell__picker-grid" role="menu">
                  {{#each this.palette as |blockEntry|}}
                    <button
                      type="button"
                      class="visual-editor-grid-cell__picker-chip"
                      role="menuitem"
                      title={{blockEntry.displayName}}
                      {{on "click" (fn this.pickBlock blockEntry)}}
                    >
                      {{dIcon blockEntry.icon}}
                      <span>{{blockEntry.displayName}}</span>
                    </button>
                  {{/each}}
                </div>
              </div>
            {{/if}}
          </div>
        {{/each}}

        <div
          class="visual-editor-grid-ghost"
          aria-hidden="true"
          {{didInsert this.captureGhost}}
        ></div>

        <div
          class="visual-editor-grid-drop-overlay {{this.overlayVariantClass}}"
          style={{this.overlayStyle}}
          aria-hidden="true"
          {{didInsert this.captureOverlay}}
        ></div>
      {{/in-element}}
    {{/if}}
  </template>
}
