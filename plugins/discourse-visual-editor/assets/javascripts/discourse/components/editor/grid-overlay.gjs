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
 * — empty-cell placeholders, slot tiles, and the drag ghost — INTO
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
 *  - A single ghost `<div>` that the drag modifier repositions during
 *    a drag to preview the proposed placement.
 *
 * Args:
 *  - `@gridKey` — the layout block's composite key (lets us locate
 *    the entry in the resolved layout via the editor service).
 *  - `@outletName` — the outlet the layout lives in.
 */
export default class GridOverlay extends Component {
  @service visualEditor;
  @service blocks;

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

  /** Ghost element ref, captured on its own insert. */
  _ghostElement = null;

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

  @action
  captureGridElement(element) {
    // The marker `<span>` is a sibling of the layout's grid div within
    // the chrome wrapper. Walk up to chrome and find the layout div so
    // `{{#in-element}}` below mounts cells / ghost as direct grid
    // children.
    this._gridElement =
      element.parentElement?.querySelector(".ve-layout--grid");
  }

  @action
  captureGhost(element) {
    this._ghostElement = element;
  }

  /**
   * Shows the drop ghost at the given cell while a drag hovers over it.
   * Drives the "overlay of the area the block will fill" UX during a
   * cross-cell drag (as requested) — same affordance the resize handle
   * already uses for span previews. Always renders the ghost at 1×1
   * for drop targets; resize spans use the modifier's own ghost moves.
   */
  @action
  showDropGhost(cell) {
    const ghost = this._ghostElement;
    if (!ghost) {
      return;
    }
    ghost.style.gridColumn = `${cell.column} / ${cell.column + 1}`;
    ghost.style.gridRow = `${cell.row} / ${cell.row + 1}`;
    ghost.classList.add("--visible");
  }

  @action
  hideDropGhost() {
    this._ghostElement?.classList.remove("--visible");
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
  applyCellDrop(cell, { source }) {
    this.hideDropGhost();
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
    this.visualEditor.endDrag?.();
  }

  @action
  onCellDragEnter(cell, { element }) {
    this.showDropGhost(cell);
    element.classList.add("--drag-target");
  }

  @action
  onCellDragLeave(_, { element }) {
    this.hideDropGhost();
    element.classList.remove("--drag-target");
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
      container the slots already live in. }}
    <span
      class="visual-editor-grid-edit-marker"
      aria-hidden="true"
      {{didInsert this.captureGridElement}}
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
      {{/in-element}}
    {{/if}}
  </template>
}
