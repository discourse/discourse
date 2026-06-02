// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { parsePlacement } from "discourse/blocks";
import { registerDragAndDropTarget } from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";
import { GRID_LAYOUT_SELECTOR } from "discourse/plugins/discourse-wireframe/discourse/lib/grid-dom";
// `grid-math` is the plugin's editor-only geometry; admin-only consumer,
// so cross-bundle imports use absolute addon paths.
import {
  computeOccupation,
  computeShiftPlan,
  computeZone,
  computeZoneCollapsed,
  unoccupiedCells,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";
import { entryKey } from "../../lib/mutate-layout";
import { buildBlockPalette } from "../../lib/palette";
import EditorEmptyDropPlaceholder from "./editor-empty-drop-placeholder";

/**
 * Shallow equivalence check for intermediate (logical) grid drop
 * descriptors. Returns true when `a` and `b` would publish the same
 * unified preview so the dragover handler can short-circuit before
 * rebuilding geometry + dispatch.
 *
 * Compares every field that influences either the overlay paint
 * (kind, column.start/end, row.start/end, line, variant, validity)
 * or the geometry pre-stamped at hit-test time in collapsed mode
 * (`_collapsedRect` coords + `_collapsedZone`).
 */
function descriptorsEqual(a, b) {
  if (a === b) {
    return true;
  }
  if (!a || !b) {
    return false;
  }
  if (a.kind !== b.kind) {
    return false;
  }
  if (a.variant !== b.variant) {
    return false;
  }
  if (a.line !== b.line) {
    return false;
  }
  if (!!a._invalid !== !!b._invalid) {
    return false;
  }
  if (a._collapsedZone !== b._collapsedZone) {
    return false;
  }
  if (a.column?.start !== b.column?.start) {
    return false;
  }
  if (a.column?.end !== b.column?.end) {
    return false;
  }
  if (a.row?.start !== b.row?.start) {
    return false;
  }
  if (a.row?.end !== b.row?.end) {
    return false;
  }
  const ra = a._collapsedRect;
  const rb = b._collapsedRect;
  if (!!ra !== !!rb) {
    return false;
  }
  if (ra && rb) {
    if (
      ra.top !== rb.top ||
      ra.left !== rb.left ||
      ra.width !== rb.width ||
      ra.height !== rb.height
    ) {
      return false;
    }
  }
  return true;
}

/**
 * Edit-mode affordances for a selected `wf:layout` in grid mode.
 *
 * Teleports its edit-mode DOM — empty-cell placeholders, slot tiles,
 * and the drop overlay — INTO the layout's own grid `<div>` via
 * `{{#in-element}}`. Cells, slots, and tiles all become direct
 * children of the same CSS Grid container, so their grid placements
 * snap to the same tracks by construction.
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
  @service wireframe;
  @service blocks;
  @service dragAndDrop;

  /**
   * The layout's grid `<div>`, located on insert via the marker's
   * sibling lookup. `{{#in-element}}` mounts the cells / tiles / ghost
   * into this element so they share the layout's CSS Grid context.
   * Tracked so the conditional `{{#if this.gridElement}}` re-renders
   * once the ref is captured.
   */
  @tracked gridElement = null;

  // Emits CSS custom properties rather than concrete `grid-column` /
  // `grid-row` so a parent `@container` rule (the auto-collapse
  // override in `wireframe-chrome.scss`) can override the cell's
  // placement when the layout collapses to one column. Inline
  // `style="grid-column: ..."` would win over any stylesheet rule;
  // the custom-property hand-off lets the stylesheet take precedence
  // when needed without `!important`. Same pattern the layout block's
  // `cellStyle` uses for `.d-block-layout__cell`.
  //
  // `order` is also set so that when the `@container` collapse rewrites
  // every cell to `grid-row: auto`, auto-placement walks the children
  // in (row, col) reading order — empty cells interleave naturally with
  // slot chromes in the stacked view. Harmless in the expanded grid
  // because explicit `grid-column` / `grid-row` placements take
  // priority over `order` there.
  cellStyle = (cell) =>
    trustHTML(
      `--wf-grid-cell-column: ${cell.column} / ${cell.column + 1}; ` +
        `--wf-grid-cell-row: ${cell.row} / ${cell.row + 1}; ` +
        `order: ${(cell.row - 1) * 1000 + (cell.column - 1)};`
    );

  /**
   * Accept palette drops AND existing-block drops. The grid-level
   * drop target dispatches whichever descriptor the dragover handler
   * has already published.
   */
  acceptedDropKinds = ["wf-block", "wf-palette-block"];

  /**
   * Per-drag geometry cache. Populated lazily on the first dragover
   * of a session (keyed on the drag source's reference identity in
   * `dragAndDrop.currentDrag`); refreshed when the window resizes or
   * any element on the page scrolls (which may shift the grid's
   * viewport-relative position); cleared when no drag is in flight.
   *
   * Avoids 2-3 synchronous layout reads per dragover —
   * `getBoundingClientRect()` and `getComputedStyle().fontSize` /
   * threshold computation. Hot during typical drags.
   *
   * Shape: `{source, gridRect, isCollapsed}` or `null`.
   */
  #dragCache = null;

  /**
   * The most recently published intermediate descriptor for this
   * drag. Drives the dragover diff in `#publishFromDrag` — if the
   * next dragover produces a shape-equivalent intermediate, we skip
   * the rebuild + service publish entirely. Cleared on dragleave.
   *
   * Holds the intermediate (logical) shape, not the unified one, so
   * the diff happens before geometry / dispatch builds.
   */
  #lastIntermediate = null;

  /**
   * Refreshes the cached gridRect + isCollapsed without dropping the
   * cache identity. Bound to window `resize` and `scroll` so coords
   * stay current if the page reflows during a drag.
   */
  #invalidateDragGeometry = () => {
    if (this.#dragCache && this.gridElement) {
      this.#dragCache.gridRect = this.gridElement.getBoundingClientRect();
      this.#dragCache.isCollapsed = this.#computeIsCollapsed();
    }
  };

  /**
   * Cleanup function returned by `registerDragAndDropTarget` for the grid
   * container's PDND drop target. Invoked once on destroy.
   */
  #gridDropTargetCleanup = null;

  /** Resize ghost element ref, captured on its own insert. */
  // eslint-disable-next-line no-unused-private-class-members
  #ghostElement = null;

  /** Drop-preview overlay element ref, captured on its own insert. */
  // eslint-disable-next-line no-unused-private-class-members
  #overlayElement = null;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#gridDropTargetCleanup?.();
    this.#gridDropTargetCleanup = null;
    window.removeEventListener("resize", this.#invalidateDragGeometry);
    window.removeEventListener("scroll", this.#invalidateDragGeometry, true);
  }

  get gridEntry() {
    // Open a tracked dep on structuralVersion so re-renders fire on
    // every layout mutation (slot insertions / removals / placement
    // changes).
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    return this.wireframe.findEntryAndOutletSync(this.args.gridKey)?.entry;
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
   * `wireframe.scss` has fired and each cell now spans all
   * columns via `grid-column: 1 / -1`. The grid container itself
   * keeps `display: grid` and its original `grid-template-columns`
   * (per the CSS spec, `@container` queries style descendants, not
   * the container element itself), so the only direct signal is the
   * container's measured width vs the SCSS thresholds.
   *
   * Drives the dispatch to the DOM-element hit-test / overlay paths
   * in `#descriptorFromCursor` and `#computeOverlayGeometry`: track
   * math doesn't fit a layout whose cells all span 1 / -1, so we
   * hand off to element lookups instead.
   *
   * The thresholds (40rem / 15rem) are duplicated from
   * `wireframe.scss` because there's no clean way to read a
   * @container's max-width from JS; if either constant changes,
   * update both sides.
   *
   * Returns `false` when an ancestor carries `.--force-expanded`
   * (the editor-only override restores per-author placements so the
   * track-math path is correct).
   */
  get isCollapsed() {
    const cache = this.#activeDragContext();
    if (cache) {
      return cache.isCollapsed;
    }
    return this.#computeIsCollapsed();
  }

  /**
   * Compact palette for the cell picker — same data as the main
   * palette but filtered to user-pickable blocks and sorted by
   * category then displayName.
   */
  @cached
  get palette() {
    return buildBlockPalette(this.blocks);
  }

  @action
  captureGridElement(element) {
    // The marker `<span>` is a sibling of the layout's grid div within
    // the chrome wrapper. Walk up to chrome and find the layout div so
    // `{{#in-element}}` below mounts cells / overlay as direct grid
    // children.
    const gridEl = element.parentElement?.querySelector(GRID_LAYOUT_SELECTOR);
    this.gridElement = gridEl;
    if (!gridEl) {
      return;
    }
    // Drive the overlay descriptor from a single grid-level drop
    // target so the overlay appears as soon as the cursor enters the
    // grid — not only when it's over a specific cell or slot. The
    // cursor's pixel position resolves to a cell coordinate via the
    // grid's resolved track sizes, then to a zone within that cell. A
    // line variant in the gap between two cells stays positioned in
    // that gap even when the cursor is mid-traverse between cells.
    //
    // The grid is the SOLE PDND target for the whole grid surface:
    // empty cells, slot chromes, and grid-positioned leaf chromes all
    // route their drops here via PDND's "closest ancestor" target
    // resolution. That keeps descriptor compute centralised — only
    // this component knows about the grid's resolved tracks.
    this.#gridDropTargetCleanup = registerDragAndDropTarget(gridEl, () => ({
      accepts: this.acceptedDropKinds,
      indicator: false,
      onDragEnter: ({ source, location }) =>
        this.#publishFromDrag(source, location),
      onDrag: ({ source, location }) => this.#publishFromDrag(source, location),
      onDragLeave: () => {
        this.#lastIntermediate = null;
        this.wireframe.setActiveDropPreview(null);
      },
      onDrop: this.handleDrop,
    }));
    // Refresh the per-drag geometry cache when the page reflows (any
    // resize) or when any scroll container moves (capture-phase
    // listener catches scrolls on nested overflow containers too, not
    // just window scroll). Keeps cached `gridRect` viewport coords
    // valid through layout shifts during a drag.
    window.addEventListener("resize", this.#invalidateDragGeometry, {
      passive: true,
    });
    window.addEventListener("scroll", this.#invalidateDragGeometry, {
      passive: true,
      capture: true,
    });
  }

  @action
  captureGhost(element) {
    this.#ghostElement = element;
  }

  @action
  captureOverlay(element) {
    this.#overlayElement = element;
  }

  /**
   * Grid-level drop handler. PDND routes every drop within the grid
   * surface (empty cells, slot chromes, grid-positioned leaves) here
   * via "closest ancestor target" resolution, since the grid div is
   * the sole PDND drop target for the surface. The dispatch payload
   * was already embedded in the active descriptor at hit-test time;
   * `dispatchActiveDrop` runs it by action name. `endDrag` is
   * dispatched by the source modifier's `onDrop` callback.
   */
  @action
  handleDrop() {
    this.#lastIntermediate = null;
    this.wireframe.dispatchActiveDrop();
  }

  @action
  pickBlockForCell(cell, blockEntry) {
    this.wireframe.insertBlockAtCell({
      gridKey: this.args.gridKey,
      blockName: blockEntry.name,
      column: cell.column,
      row: cell.row,
    });
  }

  #computeIsCollapsed() {
    const gridEl = this.gridElement;
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
   * Returns the current drag's cached geometry, or `null` when no
   * drag is in flight. Populates the cache lazily on the first call
   * of a drag session (keyed on `dragAndDrop.currentDrag`'s reference
   * identity). Invalidated by `resize` / `scroll` listeners installed
   * in `captureGridElement`.
   */
  #activeDragContext() {
    const source = this.dragAndDrop.currentDrag;
    if (!source) {
      this.#dragCache = null;
      return null;
    }
    if (this.#dragCache?.source !== source) {
      this.#dragCache = {
        source,
        gridRect: this.gridElement?.getBoundingClientRect() ?? null,
        isCollapsed: this.#computeIsCollapsed(),
      };
    }
    return this.#dragCache;
  }

  /** Cached `gridRect` for hit-test / geometry callers. */
  #getGridRect() {
    return (
      this.#activeDragContext()?.gridRect ??
      this.gridElement?.getBoundingClientRect() ??
      null
    );
  }

  /**
   * Translates an internal (logical) grid descriptor into the
   * unified `activeDropPreview` shape — viewport-coord geometry,
   * unified `kind`, validity, label, and dispatch payload — and
   * writes it to the service. Called from `#publishFromDrag`
   * after the dragover-diff has confirmed the intermediate changed.
   *
   * No-ops (publishes `null`) when geometry can't be resolved (e.g.
   * before the grid element is captured), so the overlay disappears
   * rather than freezing on stale coords.
   */
  #publishUnified(intermediate, source) {
    if (!intermediate || !this.gridElement) {
      this.wireframe.setActiveDropPreview(null);
      return;
    }
    const gridRel = this.#computeOverlayGeometry(intermediate);
    if (!gridRel) {
      this.wireframe.setActiveDropPreview(null);
      return;
    }
    const gridRect = this.#getGridRect();
    if (!gridRect) {
      this.wireframe.setActiveDropPreview(null);
      return;
    }
    this.wireframe.setActiveDropPreview({
      geometry: {
        top: gridRect.top + gridRel.top,
        left: gridRect.left + gridRel.left,
        width: gridRel.width,
        height: gridRel.height,
      },
      kind: this.#unifiedKindFor(intermediate),
      // The `_invalid` sentinel comes from `#descriptorFromCursor`'s
      // validity gate (shift-plan check). It maps to the overlay's
      // red styling AND to `dispatch: null` so `dispatchActiveDrop`
      // no-ops at drop time.
      validity: intermediate._invalid ? "invalid" : "valid",
      label: this.#labelFor(intermediate, source),
      dispatch: intermediate._invalid
        ? null
        : this.#buildDispatch(intermediate, source),
    });
  }

  #unifiedKindFor(descriptor) {
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

  #labelFor(descriptor, source) {
    if (!source) {
      return "";
    }
    const sourceName = this.#sourceDisplayName(source);
    const kind = this.#unifiedKindFor(descriptor);
    if (kind === "swap") {
      return i18n("wireframe.canvas.drop_preview.swap", {
        name: sourceName,
      });
    }
    if (kind === "replace") {
      return source.type === "wf-palette-block"
        ? i18n("wireframe.canvas.drop_preview.fill_slot", {
            name: sourceName,
          })
        : i18n("wireframe.canvas.drop_preview.move_into_slot", {
            name: sourceName,
          });
    }
    if (kind === "shift") {
      // When the insert line sits between two identifiable occupied
      // slots, name both ("between A and B") to match the stack / row
      // copy. Edge inserts (one side empty) keep the generic wording.
      const neighbors = this.#lineNeighborNames(descriptor);
      if (neighbors) {
        return source.type === "wf-palette-block"
          ? i18n("wireframe.canvas.drop_preview.add_between", {
              name: sourceName,
              before: neighbors.before,
              after: neighbors.after,
            })
          : i18n("wireframe.canvas.drop_preview.move_between", {
              name: sourceName,
              before: neighbors.before,
              after: neighbors.after,
            });
      }
      return i18n("wireframe.canvas.drop_preview.shift", {
        name: sourceName,
      });
    }
    // occupy / fallback
    return source.type === "wf-palette-block"
      ? i18n("wireframe.canvas.drop_preview.add_to_cell", {
          name: sourceName,
        })
      : i18n("wireframe.canvas.drop_preview.move_to_cell", {
          name: sourceName,
        });
  }

  #sourceDisplayName(source) {
    if (source.type === "wf-palette-block") {
      return (
        this.wireframe.lookupBlockDisplayName(source.data.blockName) ||
        source.data.blockName ||
        "block"
      );
    }
    if (source.type === "wf-block") {
      const located = this.wireframe.findEntryAndOutletSync(
        source.data.blockKey
      );
      if (located?.entry) {
        return (
          this.wireframe.lookupBlockDisplayName(located.entry.block) || "block"
        );
      }
    }
    return "block";
  }

  /**
   * Builds the `{action, args}` dispatch payload for a grid drop
   * descriptor. The service's `dispatchActiveDrop` looks up
   * `service[action]` and calls it with `args` — same contract the
   * linear pipeline uses, so grid drops route through the same
   * channel after this phase.
   *
   * Returns `null` when the descriptor doesn't carry enough info to
   * dispatch (e.g. unresolved column / row, or unsupported variant /
   * source kind). The mirror call above feeds `null` through to
   * `setActiveDropPreview`, where `dispatchActiveDrop` will then
   * no-op at drop time.
   */
  #buildDispatch(descriptor, source) {
    if (!descriptor || !source) {
      return null;
    }
    const gridKey = this.args.gridKey;

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
      return {
        action: "insertWithShift",
        args: {
          gridKey,
          dropCell,
          direction: descriptor.kind === "line-column" ? "left" : "up",
          sourceKey: source.type === "wf-block" ? source.data?.blockKey : null,
          paletteBlockName:
            source.type === "wf-palette-block" ? source.data?.blockName : null,
          paletteDefaultArgs:
            source.type === "wf-palette-block"
              ? source.data?.defaultArgs
              : null,
        },
      };
    }

    if (descriptor.kind === "rect" && descriptor.variant === "swap") {
      return {
        action: "swapSlotPlacements",
        args: {
          slotKeyA: this.#slotKeyAtPlacement(descriptor),
          slotKeyB: source.data?.blockKey ?? null,
        },
      };
    }

    if (descriptor.kind === "rect" && descriptor.variant === "replace") {
      return {
        action: "replaceSlot",
        args: {
          targetSlotKey: this.#slotKeyAtPlacement(descriptor),
          sourceSlotKey: source.data?.blockKey ?? null,
        },
      };
    }

    // `rect` / `move` — palette → insertBlockAtCell, wf-block → moveBlockToCell.
    const column = descriptor.column?.start;
    const row = descriptor.row?.start;
    if (column == null || row == null) {
      return null;
    }
    if (source.type === "wf-palette-block") {
      return {
        action: "insertBlockAtCell",
        args: {
          gridKey,
          blockName: source.data?.blockName,
          defaultArgs: source.data?.defaultArgs,
          column,
          row,
        },
      };
    }
    if (source.type === "wf-block") {
      return {
        action: "moveBlockToCell",
        args: {
          gridKey,
          sourceKey: source.data?.blockKey,
          column,
          row,
        },
      };
    }
    return null;
  }

  /**
   * Builds an intermediate descriptor from the current drag location
   * and publishes it to the unified preview if it differs from the
   * last one. Used by both `onDragEnter` and `onDrag` so the overlay
   * shows up immediately on entry and tracks the cursor continuously.
   *
   * @param {{type: string, data: Object, element: Element}} source
   * @param {{current: {input: Object}}} location
   */
  #publishFromDrag(source, location) {
    const input = location.current.input;
    const intermediate = this.#descriptorFromCursor(input, source);
    if (descriptorsEqual(this.#lastIntermediate, intermediate)) {
      return;
    }
    this.#lastIntermediate = intermediate;
    this.#publishUnified(intermediate, source);
  }

  /**
   * Finds the slot whose placement matches the rect-descriptor's
   * `column` / `row` (the slot being swapped / replaced). Returns its
   * block key, or `null` if no slot covers that rectangle.
   */
  #slotKeyAtPlacement(descriptor) {
    if (!descriptor?.column || !descriptor?.row) {
      return null;
    }
    const slot = this.#slotAtCell({
      column: descriptor.column.start,
      row: descriptor.row.start,
    });
    return slot ? entryKey(slot) : null;
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
  #descriptorFromCursor(input, source) {
    // The source can never be dropped onto itself or into any of its
    // own descendants — that would create a cycle. Hide the overlay
    // entirely when the cursor is hovering THIS grid and the source
    // either IS this grid's layout or an ancestor of it.
    const sourceKey =
      source?.type === "wf-block" ? source.data?.blockKey : null;
    if (sourceKey && this.#sourceCoversTarget(sourceKey, this.args.gridKey)) {
      return null;
    }

    if (this.isCollapsed) {
      return this.#descriptorFromCursorCollapsed(input, source, sourceKey);
    }

    const tracks = this.#readGridTracks();
    if (!tracks) {
      return null;
    }
    const gridRect = this.#getGridRect();
    if (!gridRect) {
      return null;
    }
    const x = input.clientX - gridRect.left;
    const y = input.clientY - gridRect.top;

    const cell = this.#cursorToCell(x, y, tracks);
    if (!cell) {
      return null;
    }
    const bounds = this.#cellBounds(cell, tracks);
    const zone = computeZone(
      x - bounds.left,
      y - bounds.top,
      bounds.width,
      bounds.height
    );

    const slot = this.#slotAtCell(cell);
    let descriptor;
    if (slot) {
      // Same check at the slot level — never preview a drop onto the
      // source slot itself or any slot nested inside the source.
      const slotKey = entryKey(slot);
      if (sourceKey && this.#sourceCoversTarget(sourceKey, slotKey)) {
        return null;
      }
      descriptor = this.#slotDescriptorForZone({
        slot,
        zone,
        shift: input.shiftKey,
        source,
      });
    } else {
      descriptor = this.#cellDescriptorForZone(cell, zone);
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
    // `replace` / `move`) that `#buildDispatch` switches on.
    if (!this.#canExecuteDescriptor(descriptor, source)) {
      return { ...descriptor, _invalid: true };
    }
    return descriptor;
  }

  /**
   * Collapsed-view variant of `#descriptorFromCursor`. The track-math
   * path can't run here: a multi-column logical grid that's rendering
   * as one column has `colWidths.length === 1`, so cursor X always
   * resolves to `column 1` and `#trackStart(col=3, widths)` returns
   * NaN.
   *
   * Instead we hit-test by DOM element. `elementFromPoint` finds the
   * visible slot chrome or empty-cell placeholder under the cursor;
   * its `data-wf-block-key` / `data-col` / `data-row` map back to
   * logical coordinates; cursor Y within the element's bounding rect
   * resolves a 3-zone hit test (up / center / down — left and right
   * don't have meaningful semantics in a vertical stack).
   *
   * Output is exactly the same descriptor shape as the track-math
   * path — `#publishUnified` / `#buildDispatch` and
   * `#computeOverlayGeometry` (via its own collapsed branch) consume
   * it the same way.
   */
  #descriptorFromCursorCollapsed(input, source, sourceKey) {
    const el = document.elementFromPoint(input.clientX, input.clientY);
    if (!el || !this.gridElement.contains(el)) {
      return null;
    }

    // Empty cell placeholder — check this first. Empty cells are
    // teleported directly into the grid and never contain blocks
    // with `data-wf-block-key`, so a hit on one is unambiguous.
    const emptyEl = el.closest(".wireframe-grid-cell");
    if (emptyEl && this.gridElement.contains(emptyEl)) {
      const col = parseInt(emptyEl.getAttribute("data-col"), 10);
      const row = parseInt(emptyEl.getAttribute("data-row"), 10);
      if (Number.isNaN(col) || Number.isNaN(row)) {
        return null;
      }
      const rect = emptyEl.getBoundingClientRect();
      const zone = computeZoneCollapsed(input.clientY - rect.top, rect.height);
      const base = this.#cellDescriptorForZone({ column: col, row }, zone);
      return this.#finishCollapsedDescriptor(
        this.#attachCollapsedHit(base, rect, zone),
        source
      );
    }

    // Slot — walk up `[data-wf-block-key]` ancestors until we find
    // one that's a DIRECT child of this grid's layout entry. The
    // cursor may be over a nested block inside a container slot
    // (e.g. a paragraph inside a card-shaped slot), in which case
    // `closest` returns the innermost chrome whose key isn't in
    // `this.slots`; we want the outer slot's chrome instead.
    let candidate = el.closest("[data-wf-block-key]");
    while (candidate && this.gridElement.contains(candidate)) {
      const blockKey = candidate.getAttribute("data-wf-block-key");
      const slot = this.slots.find((s) => entryKey(s) === blockKey);
      if (slot) {
        if (sourceKey && this.#sourceCoversTarget(sourceKey, blockKey)) {
          return null;
        }
        const rect = candidate.getBoundingClientRect();
        const zone = computeZoneCollapsed(
          input.clientY - rect.top,
          rect.height
        );
        const base = this.#slotDescriptorForZone({
          slot,
          zone,
          shift: input.shiftKey,
          source,
        });
        return this.#finishCollapsedDescriptor(
          this.#attachCollapsedHit(base, rect, zone),
          source
        );
      }
      candidate = candidate.parentElement?.closest("[data-wf-block-key]");
    }

    return null;
  }

  /**
   * Stamps the collapsed-view hit-test result onto the base descriptor
   * so `#computeOverlayGeometryCollapsed` can paint against the actual
   * element the cursor was over, without round-tripping through
   * logical (col, row) → DOM lookups. The latter fails for auto-placed
   * slots (whose `placement.start` is null) and for any case where
   * `#slotAtCell` can't resolve the cell back to an element.
   *
   * The viewport-coord rect is captured at hit-test time; the
   * mirroring step converts to grid-relative the same way the
   * track-math path does, so the rest of the pipeline stays uniform.
   */
  #attachCollapsedHit(descriptor, rect, zone) {
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
   * Applies the same validity gate the track-math path uses so the
   * mirrored overlay can paint in danger tones for impossible drops
   * (e.g. shift-insert that doesn't fit the grid).
   */
  #finishCollapsedDescriptor(descriptor, source) {
    if (!descriptor) {
      return null;
    }
    if (!this.#canExecuteDescriptor(descriptor, source)) {
      return { ...descriptor, _invalid: true };
    }
    return descriptor;
  }

  /**
   * Returns `true` when the dispatch built for `descriptor` + `source`
   * would produce a real change. Shift-insert descriptors call into
   * `computeShiftPlan` to see whether the cascade fits within the
   * grid; swap / replace / occupy descriptors always succeed at this
   * stage (cycle / self-drop checks already happened upstream in
   * `#descriptorFromCursor` via `#sourceCoversTarget`).
   */
  #canExecuteDescriptor(descriptor, source) {
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
        source?.type === "wf-block" ? source.data?.blockKey : null;
      // Only same-grid sources free a cell; cross-grid arrivals don't.
      let sourceInGrid = null;
      if (sourceKey) {
        const located = this.wireframe.findEntryAndOutletSync?.(sourceKey);
        if (located?.outletName === this.#outletName(this.args.gridKey)) {
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

  #outletName(blockKey) {
    return this.wireframe.findEntryAndOutletSync?.(blockKey)?.outletName;
  }

  /**
   * Returns `true` if `targetKey` IS `sourceKey` or is one of its
   * descendants. Used to block the drop preview on illegal targets
   * (a block dropped into itself or its own subtree would form a
   * cycle in the layout tree).
   */
  #sourceCoversTarget(sourceKey, targetKey) {
    if (!sourceKey || !targetKey) {
      return false;
    }
    if (sourceKey === targetKey) {
      return true;
    }
    return this.wireframe.isAncestorOf(sourceKey, targetKey);
  }

  /**
   * Maps a pixel position (relative to the grid's top-left) to a
   * 1-indexed `(column, row)` cell. Pixels falling in a column gap
   * snap to the column whose nearest edge is closer (i.e. the gap
   * is split halfway). Returns `null` when the position falls outside
   * the grid's resolved track range.
   */
  #cursorToCell(x, y, tracks) {
    const col = this.#findTrackIndex(x, tracks.colWidths, tracks.colGap);
    const row = this.#findTrackIndex(y, tracks.rowHeights, tracks.rowGap);
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
  #findTrackIndex(pos, sizes, gap) {
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
  #cellBounds(cell, tracks) {
    const left = this.#trackStart(cell.column, tracks.colWidths, tracks.colGap);
    const right = this.#trackEnd(
      cell.column + 1,
      tracks.colWidths,
      tracks.colGap
    );
    const top = this.#trackStart(cell.row, tracks.rowHeights, tracks.rowGap);
    const bottom = this.#trackEnd(
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
  #slotAtCell(cell) {
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
   * For a line-insert descriptor, resolves the display names of the two
   * occupied slots the line sits between. Returns `null` when either
   * side is empty (an edge insert with only one neighbour, or a line at
   * the grid's outer boundary) — the caller then keeps the generic
   * "neighbours shift" copy instead of naming a non-existent block.
   */
  #lineNeighborNames(descriptor) {
    let beforeCell, afterCell;
    if (descriptor.kind === "line-column") {
      const row = descriptor.row?.start;
      if (row == null) {
        return null;
      }
      beforeCell = { column: descriptor.line - 1, row };
      afterCell = { column: descriptor.line, row };
    } else if (descriptor.kind === "line-row") {
      const column = descriptor.column?.start;
      if (column == null) {
        return null;
      }
      beforeCell = { column, row: descriptor.line - 1 };
      afterCell = { column, row: descriptor.line };
    } else {
      return null;
    }

    const beforeSlot = this.#slotAtCell(beforeCell);
    const afterSlot = this.#slotAtCell(afterCell);
    if (!beforeSlot || !afterSlot) {
      return null;
    }
    return {
      before:
        this.wireframe.lookupBlockDisplayName(beforeSlot.block) || "block",
      after: this.wireframe.lookupBlockDisplayName(afterSlot.block) || "block",
    };
  }

  /**
   * Slot-level descriptor for a given zone. Center maps to a rect
   * (swap / replace if Shift, or null when the source is a palette
   * block — palette blocks can't land on an occupied cell's center).
   * Edges map to thin lines in the gap on the slot's outer perimeter.
   */
  #slotDescriptorForZone({ slot, zone, shift, source }) {
    const placement = parsePlacement(slot.containerArgs);
    const slotKey = entryKey(slot);
    if (zone === "center") {
      if (source?.type !== "wf-block") {
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
  #cellDescriptorForZone(cell, zone) {
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
  #computeOverlayGeometry(descriptor) {
    if (this.isCollapsed) {
      return this.#computeOverlayGeometryCollapsed(descriptor);
    }
    const tracks = this.#readGridTracks();
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
      const left = this.#trackStart(colStart, colWidths, colGap);
      const right = this.#trackEnd(colEnd, colWidths, colGap);
      const top = this.#trackStart(rowStart, rowHeights, rowGap);
      const bottom = this.#trackEnd(rowEnd, rowHeights, rowGap);
      return {
        left,
        top,
        width: Math.max(0, right - left),
        height: Math.max(0, bottom - top),
      };
    }

    if (descriptor.kind === "line-column") {
      const lineX = this.#lineMidpoint(descriptor.line, colWidths, colGap);
      const rowStart = descriptor.row?.start ?? 1;
      const rowEnd = descriptor.row?.end ?? rowHeights.length + 1;
      const top = this.#trackStart(rowStart, rowHeights, rowGap);
      const bottom = this.#trackEnd(rowEnd, rowHeights, rowGap);
      return {
        left: lineX - stroke / 2,
        top,
        width: stroke,
        height: Math.max(0, bottom - top),
      };
    }

    if (descriptor.kind === "line-row") {
      const lineY = this.#lineMidpoint(descriptor.line, rowHeights, rowGap);
      const colStart = descriptor.column?.start ?? 1;
      const colEnd = descriptor.column?.end ?? colWidths.length + 1;
      const left = this.#trackStart(colStart, colWidths, colGap);
      const right = this.#trackEnd(colEnd, colWidths, colGap);
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
   * Collapsed-view variant of `#computeOverlayGeometry`. Looks up the
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
  #computeOverlayGeometryCollapsed(descriptor) {
    if (!this.gridElement) {
      return null;
    }
    const rect = descriptor._collapsedRect;
    if (!rect) {
      return null;
    }
    const gridRect = this.#getGridRect();
    if (!gridRect) {
      return null;
    }
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
  #readGridTracks() {
    const gridEl = this.gridElement;
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
  #trackStart(line, sizes, gap) {
    if (line <= 1) {
      return 0;
    }
    if (line > sizes.length + 1) {
      return this.#trackEnd(sizes.length + 1, sizes, gap);
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
  #trackEnd(line, sizes, gap) {
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
  #lineMidpoint(line, sizes, gap) {
    if (line <= 1) {
      return 0;
    }
    if (line >= sizes.length + 1) {
      return this.#trackEnd(sizes.length + 1, sizes, gap);
    }
    return this.#trackEnd(line, sizes, gap) + gap / 2;
  }

  <template>
    {{! Marker — invisible. On insert, finds the sibling layout grid
      div so we can teleport the edit-mode DOM into the same CSS Grid
      container the slots already live in. }}
    <span
      class="wireframe-grid-edit-marker"
      aria-hidden="true"
      {{didInsert this.captureGridElement}}
    ></span>

    {{#if this.gridElement}}
      {{! `insertBefore=null` appends without wiping the slots already
        rendered inside the grid div. }}
      {{#in-element this.gridElement insertBefore=null}}
        {{#each this.emptyCells as |cell|}}
          <div
            class="wireframe-grid-cell"
            style={{this.cellStyle cell}}
            data-col={{cell.column}}
            data-row={{cell.row}}
          >
            <EditorEmptyDropPlaceholder
              @hint={{i18n "wireframe.canvas.empty_cell_hint"}}
              @palette={{this.palette}}
              @onPick={{fn this.pickBlockForCell cell}}
            />
          </div>
        {{/each}}

        <div
          class="wireframe-grid-ghost"
          aria-hidden="true"
          {{didInsert this.captureGhost}}
        ></div>
        {{! No local drop overlay — the shell-mounted `<DropPreview>`
          is the single indicator. The dragover handler publishes
          the unified descriptor directly to
          `wireframe.setActiveDropPreview`. }}
      {{/in-element}}
    {{/if}}
  </template>
}
