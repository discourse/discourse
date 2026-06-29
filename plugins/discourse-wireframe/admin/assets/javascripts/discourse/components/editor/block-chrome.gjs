// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import {
  DEFAULT_GRID_COLUMNS,
  DEFAULT_GRID_ROWS,
  gridDimensions,
  LAYOUT_MERGED_CELL_BLOCK,
  parsePlacement,
  parseSlotPlacement,
} from "discourse/blocks";
import { isPartKey } from "discourse/lib/blocks/-internals/composite";
import { eq } from "discourse/truth-helpers";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import { i18n } from "discourse-i18n";
// `grid-math` is the plugin's editor-only geometry; admin-only consumer,
// so cross-bundle imports use absolute addon paths.
import {
  BLOCK_ARG_ATTR,
  BLOCK_ARG_SELECTOR,
  GRID_LAYOUT_SELECTOR,
} from "discourse/plugins/discourse-wireframe/discourse/lib/editor-dom-contract";
import {
  EXTERNAL_IMAGE_DROP_SOURCE,
  firstImageFile,
} from "discourse/plugins/discourse-wireframe/discourse/lib/external-image-drop";
import {
  cellAt,
  computeOccupation,
  computeSpanResize,
  formatTrack,
  placementsOverlap,
  resizableDirections,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";
import { imageArgEntries } from "../../lib/empty-image-upload";
import { kindForArg } from "../../lib/kind-for-arg";
import { entryKey } from "../../lib/mutate-layout";
import { buildBlockPalette } from "../../lib/palette";
import {
  CHILD_LABEL_NAMESPACE_BY_PARENT,
  CHILD_NOUN_KEY_BY_PARENT,
  CHILD_NUMBER_KEY_BY_PARENT,
  richInlineToPlainText,
} from "../../lib/walk-layout";
import containerDropTarget, {
  createContainerDropResolver,
} from "../../modifiers/container-drop-target";
import proxyDragSources from "../../modifiers/proxy-drag-sources";
import { OUTLET_STATE } from "../../services/wireframe-layout-query";
import LinkEditPopover from "../link-edit-popover";
import BlockToolbar from "./block-toolbar";
import EditorEmptyDropPlaceholder from "./editor-empty-drop-placeholder";
import GridOverlay from "./grid-overlay";
import ImageArgOverlay from "./image-arg-overlay";
import ImageEditMenu from "./image-edit-menu";
import ImageResizeOverlay from "./image-resize-overlay";

/**
 * Wraps every rendered block while the editor is active so the canvas can
 * show selection chrome (an outline plus a corner handle when selected) and
 * drag-and-drop affordances (a drag handle + drop zones around the block).
 *
 * Curried into the block render path via the `BLOCK_DEBUG` debug-hook from
 * the api-initializer. When the editor is inactive, only the wrapped block
 * renders — no extra DOM and no event interception, so the host page
 * behaves exactly as it would without the plugin.
 *
 * Drag-and-drop model (chosen because HTML5 DnD on nested-draggable
 * elements is unreliable):
 *   - The chrome itself is NOT draggable. The handle region inside
 *     `BlockToolbar` (`.wireframe-block-toolbar__handle`) IS the drag
 *     source.
 *   - The toolbar is rendered always; CSS hides it until the chrome
 *     is hovered or selected. That way users grab the handle with one
 *     gesture, not two.
 *   - Drop zones (before/after siblings, optional inside-container) are
 *     siblings of the wrapped component within the chrome. They occupy
 *     real layout space (4px) at all times while the editor is active so
 *     hit-testing is reliable from the very first dragenter.
 */
export default class BlockChrome extends Component {
  @service blocks;
  @service menu;
  @service tooltip;
  @service wireframe;
  @service wireframeDragOverlay;
  @service wireframeForceExpand;
  @service wireframeIconEdit;
  @service wireframeLinkEdit;

  /**
   * Reference to the chrome's outer `<div>`, set on insert. Passed to
   * `BlockToolbar` as `@chromeEl` and used as the drag-source's drag
   * image so the browser shows a translucent copy of the actual block
   * being dragged instead of the handle tab itself (the default when
   * no `dragImage` is supplied). Tracked so the drag-source modifier
   * re-runs once the ref is captured (it installs before the chrome
   * div's `didInsert` fires, otherwise capturing a stale `null`).
   */
  @tracked chromeEl = null;

  /**
   * The most recent file dropped on the block body, handed to the
   * background overlay to upload through its own pipeline (progress bar,
   * value write). A fresh `File` per drop, so the overlay's `didUpdate`
   * fires once per drop.
   */
  @tracked pendingBackgroundFile = null;

  acceptedDragKinds = ["wf-block", "wf-palette-block"];
  /**
   * Returns the chrome element ref for use as a drag image. Passed as a
   * getter (not a value) to the drag-source modifier so it resolves at
   * dragstart, not at modifier setup time when the ref is still null.
   *
   * @returns {Element|null}
   */
  getChromeEl = () => this.chromeEl;
  /**
   * Locates the parent grid layout's grid `<div>` element so the
   * resize modifier can measure cell sizes. Walks up from this chrome's
   * own element through the DOM until it finds the grid container.
   *
   * @returns {Element|null}
   */
  getResizeGridElement = () => {
    if (!this.chromeEl) {
      return null;
    }
    return this.chromeEl.closest(GRID_LAYOUT_SELECTOR);
  };
  /**
   * Returns the ghost element rendered inside the parent grid by the
   * grid overlay. Re-queried on each pointerdown via this getter
   * because the grid overlay re-renders independently.
   *
   * @returns {Element|null}
   */
  getResizeGhost = () => {
    const grid = this.getResizeGridElement();
    return grid?.querySelector(".wireframe-grid-ghost") ?? null;
  };
  /**
   * The set of grid cells occupied by SIBLING entries (this block excluded),
   * keyed `"row,col"`. Captured at the start of a span-resize so the gesture
   * can clamp a growing edge at the first occupied neighbour and never commit
   * an overlapping placement. Reads through the service (opens a tracked dep
   * on `structuralVersion`) so it reflects the live layout.
   *
   * @returns {Set<string>}
   */
  getResizeOccupied = () => {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const grid = this.wireframe.layoutQuery.findEntryParent(this.args.blockKey);
    if (!grid) {
      return new Set();
    }
    // Use the EFFECTIVE grid size (what's actually rendered), not the declared
    // `args` size, so a sibling spanning past the declared count is still
    // counted as occupied. Same source the renderer uses, so they can't drift.
    const { columns, rows } = gridDimensions(
      {
        columns: grid.args?.columns ?? DEFAULT_GRID_COLUMNS,
        rows: grid.args?.rows ?? DEFAULT_GRID_ROWS,
      },
      grid.children
    );
    const selfKey = this.args.blockKey;
    const siblings = (grid.children ?? []).filter(
      (child) => entryKey(child) !== selfKey
    );
    return computeOccupation(siblings, columns, rows);
  };
  /**
   * Finds the rendered image marker (`[data-block-arg="<argName>"]`)
   * inside the chrome. Used both as the resize-handle anchor (via
   * `getMarkerEl` on `ImageResizeOverlay`) and as the source of truth
   * for the live preview during a drag.
   *
   * Returns `null` until the chrome's content has been laid out (the
   * marker is rendered by the wrapped block, not by the chrome).
   *
   * @returns {Element|null}
   */
  getImageMarkerEl = () => {
    const arg = this.resizableImageArg;
    if (!arg || !this.chromeEl) {
      return null;
    }
    // Pick the visible `<img>` / `<picture>` painted by the block,
    // not the overlay siblings (the filled image-arg overlay also
    // carries `data-block-arg` for its own click / drop dispatch).
    const escaped = CSS.escape(arg.name);
    return this.chromeEl.querySelector(
      `img[data-block-arg="${escaped}"], picture[data-block-arg="${escaped}"]`
    );
  };

  /**
   * Release callback for this chrome's current drag-overlay claim, or `null`.
   * Stored each time the chrome claims the single overlay slot (background
   * fill or slot-insert) so a dragleave releases exactly that claim.
   */
  #releaseDrop = null;

  /**
   * The container drop resolver built on external-drag enter and reused for
   * the rest of that drag, so the drop preview tracks the cursor through the
   * same geometry the block-drag path uses. Cleared on leave / drop.
   */
  #externalDropResolver = null;

  /**
   * Registered URL-edit tooltips for this block. Cleaned up in
   * `willDestroy`. Hover bridging between the link trigger and the
   * floating chip is handled by float-kit via `hoverGracePeriod`, so
   * the chrome doesn't own any extra listener teardown.
   *
   * @type {any[]}
   */
  #urlTooltips = [];

  /**
   * The active span-resize session, or `null` when no resize is in progress.
   * Captured on `onGridResizeStart` and cleared on end/cancel. Holds the
   * resolved origin placement, the snapshotted occupancy + grid rect + effective
   * dimensions (so the math is stable across the drag), the ghost element, and
   * the latest computed placement to commit.
   *
   * @type {?Object}
   */
  #gridResize = null;

  willDestroy() {
    super.willDestroy(...arguments);
    for (const instance of this.#urlTooltips) {
      instance.destroy?.();
    }
    this.#urlTooltips.length = 0;
  }

  /**
   * Block metadata (description, namespace, isContainer, args schema, etc.)
   * for the wrapped block, or `null` if the registry has no entry for this
   * block name.
   *
   * `@cached` memoises the lookup per component instance so the registry
   * isn't walked on every getter read.
   */
  @cached
  get metadata() {
    const index = this.blocks
      .listBlocksWithMetadata()
      .reduce((m, e) => m.set(e.name, e.metadata), new Map());
    return index.get(this.args.blockName) ?? null;
  }

  /** @returns {boolean} */
  get isSelected() {
    return this.wireframe.isBlockSelected(this.args.blockKey);
  }

  /** @returns {boolean} */
  get isContainer() {
    return this.metadata?.isContainer ?? false;
  }

  /**
   * Whether the wrapped block is a grid cell occupant — i.e. its entry
   * carries `containerArgs.grid` (a direct child of a `wf:layout` in
   * grid mode). The chrome reads this to drive cell-specific UX:
   * resize handle visibility, suppression of sibling drop zones, and
   * overlap / out-of-bounds warning badges.
   *
   * The placement style itself is applied higher up by core's
   * `WrappedBlockLayout` from the same `containerArgs.grid` bag — the
   * chrome stays out of layout concerns.
   *
   * @returns {boolean}
   */
  get isGridCell() {
    return this.gridPlacement != null;
  }

  /**
   * Live `containerArgs.grid` for this block, or `null` when the block
   * doesn't sit in a grid. Reads through the wireframe service
   * (opens a tracked dep on `structuralVersion`) so placement commits
   * trigger re-evaluation; the curried `@blockArgs` snapshot taken at
   * chrome-curry time wouldn't pick up the change.
   *
   * @returns {Object|null}
   */
  get gridPlacement() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const entry = this.wireframe.layoutQuery.findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    return entry?.containerArgs?.grid ?? null;
  }

  /**
   * Inline style for the chrome's inner `__content` wrapper. That
   * wrapper is a single-cell sub-grid; its `place-items` positions the
   * one element it contains (the wrapped block) per the user's
   * `align` / `justify` choice. The chrome itself always stretches to
   * fill the grid cell — its border traces the full cell rectangle —
   * so per-cell alignment lives one level deeper, on the content area.
   *
   * @returns {ReturnType<typeof trustHTML>|null}
   */
  get contentStyle() {
    const grid = this.gridPlacement;
    if (!grid) {
      return null;
    }
    const align = grid.align ?? "stretch";
    const justify = grid.justify ?? "stretch";
    return trustHTML(
      `display: grid; place-items: ${align} ${justify}; ` +
        `min-width: 0; min-height: 0;`
    );
  }

  /**
   * Whether the wrapped block is a `wf:layout` in `grid` mode (the
   * per-cell editor target). Reads the LIVE entry args via the editor
   * service rather than the curried `@blockArgs` snapshot — that
   * snapshot doesn't reactively update when the inspector mutates the
   * layout's `mode`, so flipping to Grid would otherwise leave the
   * overlay un-mounted.
   *
   * Accepts the legacy `"free-grid"` mode value as an alias for
   * `"grid"` so existing saved layouts keep working.
   *
   * Opens a tracked dep on `structuralVersion` so this re-evaluates
   * every time the layout changes.
   *
   * @returns {boolean}
   */
  get isGridLayout() {
    if (this.args.blockName !== "layout") {
      return false;
    }
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const entry = this.wireframe.layoutQuery.findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    const mode = entry?.args?.mode ?? this.args.blockArgs?.mode ?? "stack";
    return mode === "grid" || mode === "free-grid";
  }

  /**
   * `true` when this chrome wraps a `wf:layout` whose key is in the
   * editor service's force-expand set. The wrapper's `--force-expanded`
   * modifier defeats the universal `@container` collapse rule so the
   * author can edit the full multi-column structure even when the
   * canvas is narrow enough to trigger collapse on the live page.
   *
   * @returns {boolean}
   */
  get isForceExpanded() {
    return (
      this.args.blockName === "layout" &&
      this.wireframeForceExpand.isForceExpanded(this.args.blockKey)
    );
  }

  /**
   * Resolves the drop-mode the `containerDropTarget` modifier should
   * use for this chrome. Returns `null` for non-container blocks (the
   * modifier is a no-op on them — leaf blocks never act as drop
   * targets directly; their parent container handles it).
   *
   * For `layout` containers we read `args.mode` (live entry, falls
   * back to the curry snapshot at chrome creation time). For other
   * container blocks we default to `"stack"` since their children
   * stack vertically.
   *
   * @returns {"stack"|"row"|"cell"|"grid"|"grid-cell-leaf"|null}
   */
  get containerDropMode() {
    if (this.isEmptyCell) {
      return "cell";
    }
    if (!this.isContainer) {
      // Leaves in a parent grid still need to BE a drop target so
      // the grid overlay's swap / shift dispatch has an element-
      // level landing surface. Stack / row leaves don't — their
      // parent container handles drops near them.
      return this.isGridCell ? "grid-cell-leaf" : null;
    }
    if (this.args.blockName !== "layout") {
      return "stack";
    }
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const entry = this.wireframe.layoutQuery.findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    const mode = entry?.args?.mode ?? this.args.blockArgs?.mode ?? "stack";
    if (mode === "row") {
      return "row";
    }
    if (mode === "grid" || mode === "free-grid") {
      return "grid";
    }
    return "stack";
  }

  /**
   * Whether to mount the grid overlay (cell placeholders + drag ghost).
   * Always mounts while the editor is active and the block is a
   * `wf:layout` in grid mode — gating on selection meant the cells
   * disappeared as soon as the user clicked into a slot's content,
   * AND meant existing grids on page load showed no cells at all
   * until the author hunted for and clicked the layout. The cell
   * placeholders share the chrome's visual language so showing them
   * for every grid layout is consistent with how the editor surfaces
   * other block boundaries.
   *
   * @returns {boolean}
   */
  get showsGridOverlay() {
    return this.isGridLayout && !this.args.isGhost;
  }

  /**
   * Current placement (`{column, row}`) of this block when it sits in a
   * grid. Drives the resize modifier mounted on the chrome wrapper.
   *
   * @returns {{column: string, row: string}}
   */
  get slotPlacement() {
    const placement = this.gridPlacement ?? {};
    return {
      column: placement.column ?? "auto",
      row: placement.row ?? "auto",
    };
  }

  /**
   * Columns count of the parent grid layout. Drives the resize modifier's snap
   * math. Reports the EFFECTIVE size (what's actually rendered —
   * `gridDimensions` of the declared args plus the children's extent), not the
   * declared `args.columns`, so the pointer-to-cell mapping matches the grid the
   * author sees and a span can't be dragged past the rightmost rendered column.
   *
   * @returns {number}
   */
  get slotGridColumns() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const grid = this.wireframe.layoutQuery.findEntryParent(this.args.blockKey);
    return gridDimensions(
      {
        columns: grid?.args?.columns ?? DEFAULT_GRID_COLUMNS,
        rows: grid?.args?.rows ?? DEFAULT_GRID_ROWS,
      },
      grid?.children
    ).columns;
  }

  /** @returns {number} */
  get slotGridRows() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const grid = this.wireframe.layoutQuery.findEntryParent(this.args.blockKey);
    return gridDimensions(
      {
        columns: grid?.args?.columns ?? DEFAULT_GRID_COLUMNS,
        rows: grid?.args?.rows ?? DEFAULT_GRID_ROWS,
      },
      grid?.children
    ).rows;
  }

  /**
   * The compass directions this grid cell can effectively resize toward, so
   * only the handles that would actually move it are rendered. An edge at the
   * grid boundary or blocked by a neighbouring cell — with no span to shrink on
   * that axis — is omitted; a corner needs both of its edges.
   *
   * @returns {Array<string>}
   */
  get gridResizeDirections() {
    return resizableDirections({
      origin: parseSlotPlacement(this.slotPlacement),
      columns: this.slotGridColumns,
      rows: this.slotGridRows,
      occupied: this.getResizeOccupied(),
    });
  }

  /**
   * Whether this cell's rectangle overlaps a sibling cell in the same
   * grid layout. Drives the `--overlapping` class so the author sees
   * an accidental collision after a resize past a neighbour.
   *
   * Auto-placed cells are excluded (CSS auto-flow handles them).
   *
   * @returns {boolean}
   */
  get hasGridOverlap() {
    if (!this.isGridCell) {
      return false;
    }
    const myPlacement = parsePlacement(
      this.wireframe.layoutQuery.findEntryAndOutletSync(this.args.blockKey)
        ?.entry?.containerArgs
    );
    if (myPlacement.column.start == null || myPlacement.row.start == null) {
      return false;
    }
    const grid = this.wireframe.layoutQuery.findEntryParent(this.args.blockKey);
    if (!grid?.children?.length) {
      return false;
    }
    for (const sibling of grid.children) {
      if (entryKey(sibling) === this.args.blockKey) {
        continue;
      }
      const theirPlacement = parsePlacement(sibling.containerArgs);
      if (placementsOverlap(myPlacement, theirPlacement)) {
        return true;
      }
    }
    return false;
  }

  /**
   * Whether this cell's explicit placement references column / row
   * lines outside the parent grid's declared `columns` × `rows`.
   * Out-of-bounds cells render in implicit (auto-sized) tracks past
   * the grid's edge, which usually looks wrong — flag them so the
   * author can see which block matches the inspector's warning
   * banner. Same danger treatment as the overlap state.
   *
   * Auto-placed cells are excluded.
   *
   * @returns {boolean}
   */
  get isOutOfBounds() {
    if (!this.isGridCell) {
      return false;
    }
    const grid = this.wireframe.layoutQuery.findEntryParent(this.args.blockKey);
    if (!grid) {
      return false;
    }
    const maxColumns = Number(grid.args?.columns ?? DEFAULT_GRID_COLUMNS);
    const maxRows = Number(grid.args?.rows ?? DEFAULT_GRID_ROWS);
    const placement = parsePlacement(
      this.wireframe.layoutQuery.findEntryAndOutletSync(this.args.blockKey)
        ?.entry?.containerArgs
    );
    const colExceeds =
      placement.column.start != null &&
      placement.column.end != null &&
      placement.column.end > maxColumns + 1;
    const rowExceeds =
      placement.row.start != null &&
      placement.row.end != null &&
      placement.row.end > maxRows + 1;
    return colExceeds || rowExceeds;
  }

  /**
   * Whether to render the generic `--inside` drop zone. Free-grid
   * layouts manage their own per-cell drop targets via the grid
   * overlay's `+` placeholders, so the catch-all drop zone (and its
   * "Drag a block here" / "Drop inside" label) would be redundant
   * for them.
   *
   * @returns {boolean}
   */
  get showsInsideDropZone() {
    return this.isContainer && !this.isGridLayout && !this.args.isGhost;
  }

  /**
   * Whether this chrome wraps a synthesized composite part (no persisted
   * entry). Parts can't be reordered, repositioned, or removed, so the
   * chrome drops their drop zones and the canvas styles them distinctly
   * (the `--part` modifier).
   *
   * @returns {boolean}
   */
  get isPart() {
    return isPartKey(this.args.blockKey);
  }

  /**
   * Whether to render the before/after sibling drop zones around this
   * chrome. In a stack/row layout they let authors drop blocks
   * adjacent to existing siblings; inside a grid cell there's no
   * "before/after" — placement is by cell coordinate — so the zones
   * are meaningless and (because they take real flow space) actively
   * misalign the chrome with the grid cell. Skip them. A synthesized part
   * can't be repositioned among siblings either, so skip them there too.
   *
   * @returns {boolean}
   */
  get showsSiblingDropZones() {
    return !this.isGridCell && !this.args.isGhost && !this.isPart;
  }

  /**
   * The layout axis of this block's parent — `"horizontal"` for a
   * `wf:layout` in row mode, `"vertical"` for stack mode (the default),
   * `null` otherwise (outlet root, grid cell, non-layout container).
   *
   * Drives the orientation of the `--before` / `--after` sibling drop
   * zones: horizontal axis = vertical strips on the left/right;
   * vertical axis = horizontal strips above/below. Without this,
   * "before / after" in a row layout would render as zones ABOVE / BELOW
   * the block, which doesn't match where its siblings actually are.
   *
   * @returns {"horizontal"|"vertical"|null}
   */
  get parentLayoutAxis() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const parent = this.wireframe.layoutQuery.findEntryParent(
      this.args.blockKey
    );
    if (!parent) {
      return null;
    }
    if (this.wireframe.layoutQuery.blockNameOf(parent) !== "layout") {
      return null;
    }
    const mode = parent.args?.mode ?? "stack";
    if (mode === "row") {
      return "horizontal";
    }
    if (mode === "stack") {
      return "vertical";
    }
    return null;
  }

  /**
   * Whether the wrapped block is a container with no children. Containers
   * normally render via `{{#each @children}}` so an empty one produces
   * zero DOM and the inside-drop zone collapses to nothing visible.
   * When this flips true, the template renders a labelled empty-state
   * hint so authors can see (and aim at) the drop target.
   *
   * Resolved live from the wireframe service rather than via a
   * curry arg — the BLOCK_DEBUG payload `blockData` doesn't carry the
   * children list (verified in
   * `frontend/discourse/app/blocks/block-outlet.gjs`), so the prior
   * `blockData.children?.length` curry was always `0`, marking every
   * container as empty.
   *
   * @returns {boolean}
   */
  get isEmptyContainer() {
    if (!this.isContainer) {
      return false;
    }
    // Free-grid layouts have their own empty-state affordance — the
    // edit-mode cell placeholders rendered by `<GridOverlay>` — so the
    // generic "Drag a block here" hint would be redundant (and would
    // sit at the wrong position visually, below the grid). Skip the
    // empty-container path for them.
    if (this.isGridLayout) {
      return false;
    }
    // Open a tracked dep on structuralVersion so this re-evaluates
    // after every layout mutation (insert / remove / move).
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const entry = this.wireframe.layoutQuery.findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    // A composite renders a code-defined composition when it carries no
    // `children` of its own; that's not an empty container needing a drop
    // hint. (Synthesized parts have no persisted entry, so `entry` is null —
    // still composed.) A detached composite has an explicit `children` array
    // and falls through to the normal empty check below.
    if (this.metadata?.parts && entry?.children == null) {
      return false;
    }
    return !entry?.children?.length;
  }

  /**
   * Image args declared on the wrapped block plus their live values
   * and emptiness. Drives the per-arg overlays painted over the block
   * content. The block always renders a marker for each image arg
   * (the real image when filled, a collapsed slot when empty), and the
   * chrome paints the affordance over that marker — empty or filled.
   *
   * The `key` folds emptiness into the `{{#each}}` identity so an arg
   * flipping empty↔filled remounts its overlay, letting each mode wire
   * its own upload lifecycle cleanly instead of reconfiguring in place.
   *
   * @returns {Array<{name: string, def: Object, value: any, isEmpty: boolean, key: string}>}
   */
  get imageArgEntries() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const entry = this.wireframe.layoutQuery.findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    return imageArgEntries(this.metadata?.args, entry?.args).map((e) => ({
      ...e,
      key: `${e.name}:${e.isEmpty}`,
    }));
  }

  /**
   * `true` when any image arg carries a `url` but no intrinsic
   * dimensions — i.e. the URL probe failed (404, CORS, slow load).
   * Drives an in-chrome warning badge so the author can see something
   * is off without opening the inspector. Also keeps the chrome at a
   * minimum height so a fully-broken image doesn't collapse to a
   * sliver.
   *
   * @returns {boolean}
   */
  get hasUnresolvedImageArg() {
    return this.imageArgEntries.some(
      (e) => !e.isEmpty && (!e.value?.width || !e.value?.height)
    );
  }

  /**
   * `true` when the block declares at least one image arg that opts
   * into drag-resize (`allowResize: true`) AND the block isn't sitting
   * in a grid cell (where the grid handle owns sizing already).
   *
   * @returns {boolean}
   */
  get showsImageResizeHandle() {
    if (this.isGridCell || !this.isSelected) {
      return false;
    }
    // The 8-point handles need a measurable rect to anchor to. When
    // the URL probe failed (the value has a `url` but no `width` /
    // `height`), the rendered image collapses to whatever the
    // browser falls back to — usually `0×0` — and the overlay's
    // positioning math produces invalid coordinates. Skip the
    // handles in that case; the chrome already shows the probe-fail
    // badge so the user has a clear signal.
    return this.imageArgEntries.some(
      (e) =>
        e.def?.allowResize === true &&
        !e.isEmpty &&
        e.value?.width > 0 &&
        e.value?.height > 0
    );
  }

  /**
   * Aspect ratio (width / height) to lock the resize drag to. Prefers
   * the schema's explicit `aspectRatio` when set to a number; falls
   * back to the light variant's intrinsic ratio; otherwise `null`
   * (free drag).
   *
   * @returns {number|null}
   */
  get imageResizeAspectRatio() {
    for (const { def, value } of this.imageArgEntries) {
      if (!def?.allowResize) {
        continue;
      }
      if (typeof def.aspectRatio === "number" && def.aspectRatio > 0) {
        return def.aspectRatio;
      }
      if (value?.width && value?.height) {
        return value.width / value.height;
      }
    }
    return null;
  }

  /**
   * The first resizable image arg on this block (or `null`). Drives
   * which arg the corner handle writes back to; multi-image blocks
   * (e.g. media-card avatar + cover) typically declare only one of
   * the two as `allowResize: true`.
   *
   * @returns {{name: string, def: Object, value: any}|null}
   */
  get resizableImageArg() {
    return (
      this.imageArgEntries.find((e) => e.def?.allowResize === true) ?? null
    );
  }

  /**
   * `true` when the resizable image arg's current display dims
   * diverge from its natural dims — used to enable the toolbar
   * "Reset to natural" button.
   *
   * @returns {boolean}
   */
  get imageIsResized() {
    const v = this.resizableImageArg?.value;
    if (!v?.naturalWidth || !v?.naturalHeight || !v?.width || !v?.height) {
      return false;
    }
    return v.width !== v.naturalWidth || v.height !== v.naturalHeight;
  }

  /**
   * `true` when the resizable image arg is smaller than its
   * containing chrome — i.e. there's room to "Fill block". When the
   * image already fills the block (or exceeds it), the button is
   * uninformative and should be hidden.
   *
   * @returns {boolean}
   */
  get imageCanFillBlock() {
    const arg = this.resizableImageArg;
    if (!arg?.value?.width || !arg?.value?.height || !this.chromeEl) {
      return false;
    }
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const rect = this.chromeEl.getBoundingClientRect();
    return (
      rect.width > arg.value.width + 1 || rect.height > arg.value.height + 1
    );
  }

  /**
   * Whether this chrome wraps an outlet's implicit root `layout` block. The
   * root IS the outlet, so its chrome presents as the outlet (labelled by
   * outlet name) and suppresses block-level affordances — moving, duplicating
   * or deleting a page region makes no sense.
   *
   * @returns {boolean}
   */
  get isOutletRoot() {
    return this.wireframe.layoutQuery.isOutletRoot(this.args.blockKey);
  }

  /**
   * The toolbar badge label — the block's own display name (e.g. "Layout", or
   * the outlet name at the outlet root). A child of an ordinal-naming container
   * shows its position ("Tab 2" / "Slide 2") as a SEPARATE chip via
   * `childOrdinal` / the toolbar's `@displayChip`, not in this label.
   *
   * @returns {string}
   */
  get displayName() {
    return this.#baseDisplayName;
  }

  /**
   * The block's own name, independent of any parent-aware ordinal override.
   *
   * @returns {string}
   */
  get #baseDisplayName() {
    // The implicit root layout reads as the outlet itself, not "Layout" —
    // show the outlet's friendly display name, falling back to its raw name.
    if (this.isOutletRoot) {
      return (
        this.blocks.getOutletMetadata(this.args.outletName)?.displayName ??
        this.args.outletName
      );
    }
    // Prefer the block's human-readable display name over its namespace-less
    // short name, then the raw block name for unregistered blocks.
    return (
      this.metadata?.displayName ??
      this.metadata?.shortName ??
      this.args.blockName
    );
  }

  /**
   * The block's parent entry, the parent's block name, and the block's index
   * among the parent's children — the basis for parent-aware naming and the
   * reorder-axis decision. `null` when the block has no parent (outlet root).
   *
   * @returns {{ parent: Object, parentName: string|null, index: number }|null}
   */
  get #parentContext() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const parent = this.wireframe.layoutQuery.findEntryParent(
      this.args.blockKey
    );
    if (!parent) {
      return null;
    }
    const index = (parent.children ?? []).findIndex(
      (child) => entryKey(child) === this.args.blockKey
    );
    return {
      parent,
      parentName: this.wireframe.layoutQuery.blockNameOf(parent),
      index,
    };
  }

  /**
   * For a child of an ordinal-naming container (a carousel slide, a tabs
   * panel), its 1-based position ("Slide 2" / "Tab 2"); `null` otherwise. Shown
   * as a chip beside the block name in the toolbar badge.
   *
   * @returns {string|null}
   */
  get childOrdinal() {
    const ctx = this.#parentContext;
    const numberKey = ctx?.parentName
      ? CHILD_NUMBER_KEY_BY_PARENT[ctx.parentName]
      : null;
    if (!numberKey || ctx.index < 0) {
      return null;
    }
    return i18n(numberKey, { number: ctx.index + 1 });
  }

  /**
   * The hover tooltip for an ordinal-named child: its author-set label when the
   * parent labels its children (a tab's "Pricing"). `null` when the child has no
   * label (or isn't a labelled-container child), so the badge keeps its default
   * title — the block name is already visible in the badge itself.
   *
   * @returns {string|null}
   */
  get childTooltip() {
    const ctx = this.#parentContext;
    const namespace = ctx?.parentName
      ? CHILD_LABEL_NAMESPACE_BY_PARENT[ctx.parentName]
      : null;
    if (!namespace) {
      return null;
    }
    const located = this.wireframe.layoutQuery.findEntryAndOutletSync(
      this.args.blockKey
    );
    const label = richInlineToPlainText(
      located?.entry?.containerArgs?.[namespace]?.label
    ).trim();
    return label || null;
  }

  /**
   * The axis along which the block's siblings are arranged, so the toolbar
   * shows the matching reorder arrows: "horizontal" for a tabs / carousel
   * parent and a `layout` in row mode, "vertical" otherwise (a grid keeps
   * vertical arrows this round). Distinct from `parentLayoutAxis`, which drives
   * drop-zone CSS for `layout` containers only.
   *
   * @returns {"horizontal"|"vertical"}
   */
  get siblingMoveAxis() {
    const ctx = this.#parentContext;
    const name = ctx?.parentName;
    if (name === "tabs" || name === "carousel") {
      return "horizontal";
    }
    if (name === "layout" && (ctx.parent.args?.mode ?? "stack") === "row") {
      return "horizontal";
    }
    return "vertical";
  }

  /**
   * The empty-state placeholder's hint. A container that frames its children
   * with a noun (a tabs block, a carousel) reads "Add a tab to get started" /
   * "Add a slide to get started"; any other empty container keeps the generic
   * "Drag a block here".
   *
   * @returns {string}
   */
  get emptyHint() {
    const nounKey = CHILD_NOUN_KEY_BY_PARENT[this.args.blockName];
    if (nounKey) {
      return i18n("wireframe.canvas.empty_hint_child", { noun: i18n(nounKey) });
    }
    return i18n("wireframe.canvas.empty_hint");
  }

  /**
   * The persistence state of the outlet this block belongs to (one of
   * `OUTLET_STATE`). Drives the outlet-root badge and the read-only suppression.
   *
   * @returns {string}
   */
  get outletState() {
    return this.wireframe.layoutQuery.outletState(this.args.outletName);
  }

  /**
   * Whether this block sits inside a read-only (LOCKED) outlet — owned by a
   * non-overridable programmatic layout. Every block in such an outlet (root
   * and descendants share the outlet name) suppresses selection and the
   * toolbar, so the locked layout can't be edited.
   *
   * @returns {boolean}
   */
  get isReadOnlyOutlet() {
    return this.outletState === OUTLET_STATE.LOCKED;
  }

  /** @returns {boolean} */
  get isOutletEditing() {
    return this.wireframe.isOutletEditing(this.args.outletName);
  }

  /**
   * Whether this outlet root currently holds no content blocks — the
   * "start a layout from scratch" case (a freshly mounted or just-reset
   * outlet whose root `layout` block has no children).
   *
   * @returns {boolean}
   */
  get isEmptyOutletRoot() {
    if (!this.isOutletRoot) {
      return false;
    }
    // Open a tracked dep on structuralVersion so this re-evaluates after every
    // layout mutation (the first dropped block flips it non-empty).
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const entry = this.wireframe.layoutQuery.findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    return !entry?.children?.length;
  }

  /**
   * Whether the outlet badge should render its status chip. An empty,
   * default outlet (nothing built yet, nothing owns it) shows just its
   * name — a "Default" chip on an empty region is noise. Every other case
   * (an edit in progress, a published or locked outlet, or a default
   * outlet that actually has content) shows the chip.
   *
   * @returns {boolean}
   */
  get showOutletStatus() {
    if (this.isOutletEditing) {
      return true;
    }
    return !(
      this.outletState === OUTLET_STATE.DEFAULT && this.isEmptyOutletRoot
    );
  }

  /**
   * Merged-cell entries are empty grid cells. The chrome wraps them
   * like any other block (selection, drag, resize via the existing
   * grid handle), but the inner render area becomes a "Pick a block"
   * placeholder instead of the cell's no-op template, and drops route
   * through `placeBlockInCell` / `moveBlockIntoCell` so the cell is
   * filled by content rather than inserted-as-sibling.
   *
   * @returns {boolean}
   */
  get isEmptyCell() {
    return this.args.blockName === LAYOUT_MERGED_CELL_BLOCK;
  }

  /**
   * Palette for the slot/container picker popovers — same data the
   * grid overlay and the outlet boundary use. Cached so the same list
   * reference flows into every empty-state placeholder this chrome
   * renders.
   *
   * @returns {Array<{name: string, metadata: Object}>}
   */
  @cached
  get palette() {
    return buildBlockPalette(this.blocks);
  }

  /**
   * Resize drag's live preview handler. Applies the proposed
   * dimensions directly to the IMAGE MARKER (not the chrome) via
   * inline style so the user sees the size change as they drag
   * without committing each frame to the layout — and so the overlay's
   * ResizeObserver sees the change and re-positions the 8 handles to
   * track the live preview.
   *
   * @param {{width: number, height: number}} dims
   */
  @action
  previewImageResize({ width, height }) {
    const marker = this.getImageMarkerEl();
    if (!marker) {
      return;
    }
    marker.style.width = `${width}px`;
    marker.style.height = `${height}px`;
  }

  /**
   * Commits the final resize dimensions back into the image arg's own
   * `width` / `height`. Writing to the arg (not `containerArgs.size`)
   * means the live site picks up the new dimensions for free — the
   * renderer already forwards `image.width` / `image.height` to the
   * underlying `<img>` element's attributes.
   *
   * Drops the inline preview style on the MARKER so the committed
   * value drives layout (otherwise the inline style would stick
   * around and shadow future adjustments).
   *
   * @param {{width: number, height: number}} dims
   */
  @action
  commitImageResize({ width, height }) {
    const marker = this.getImageMarkerEl();
    if (marker) {
      marker.style.width = "";
      marker.style.height = "";
    }
    if (this.chromeEl) {
      this.chromeEl.style.width = "";
      this.chromeEl.style.height = "";
    }
    const arg = this.resizableImageArg;
    if (!arg) {
      return;
    }
    // Preserve `naturalWidth` / `naturalHeight` (set at upload /
    // probe time) so the inspector can offer "Reset to natural" and
    // we can show the resized info bar. Resize only changes the
    // DISPLAY dimensions (`width` / `height`), not the intrinsic
    // ones.
    const naturalWidth = arg.value?.naturalWidth ?? arg.value?.width;
    const naturalHeight = arg.value?.naturalHeight ?? arg.value?.height;
    const nextValue = {
      ...(arg.value ?? {}),
      width,
      height,
      naturalWidth,
      naturalHeight,
    };
    this.wireframe.setImageArg(this.args.blockKey, arg.name, nextValue);
  }

  /**
   * Resets the resizable image arg's display dimensions to its
   * natural / intrinsic size. Wired to the toolbar "Reset to
   * natural" button.
   */
  @action
  resetImageToNaturalSize() {
    const arg = this.resizableImageArg;
    if (!arg?.value?.naturalWidth || !arg?.value?.naturalHeight) {
      return;
    }
    this.wireframe.setImageArg(this.args.blockKey, arg.name, {
      ...arg.value,
      width: arg.value.naturalWidth,
      height: arg.value.naturalHeight,
    });
  }

  /**
   * Resizes the image arg to fit inside its containing chrome with
   * the aspect ratio preserved (object-fit: contain semantics). One
   * dimension matches the chrome; the other has margin. Natural
   * dimensions are preserved so a subsequent "Reset to natural"
   * still works.
   */
  @action
  fillImageToBlock() {
    const arg = this.resizableImageArg;
    if (!arg?.value || !this.chromeEl) {
      return;
    }
    const rect = this.chromeEl.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }
    const naturalWidth = arg.value.naturalWidth ?? arg.value.width;
    const naturalHeight = arg.value.naturalHeight ?? arg.value.height;
    if (!naturalWidth || !naturalHeight) {
      return;
    }
    const imageAspect = naturalWidth / naturalHeight;
    const blockAspect = rect.width / rect.height;
    let width;
    let height;
    if (imageAspect > blockAspect) {
      // Image is wider than the block: width maxes out, height
      // shrinks to maintain aspect.
      width = rect.width;
      height = rect.width / imageAspect;
    } else {
      // Image is taller (or equal): height maxes out, width
      // shrinks.
      height = rect.height;
      width = rect.height * imageAspect;
    }
    this.wireframe.setImageArg(this.args.blockKey, arg.name, {
      ...arg.value,
      width: Math.round(width),
      height: Math.round(height),
      naturalWidth,
      naturalHeight,
    });
  }

  /**
   * Fills this empty cell with the block the user picked from the
   * palette placeholder. Routes through `placeBlockInCell` so the cell
   * entry is REPLACED by the new block rather than inserted alongside
   * it.
   *
   * @param {{name: string}} blockEntry - Palette entry the user selected.
   */
  @action
  pickBlockForCell(blockEntry) {
    this.wireframe.placeBlockInCell({
      cellKey: this.args.blockKey,
      blockName: blockEntry.name,
    });
  }

  /**
   * Inserts the picked block as a new child INSIDE this empty container.
   * Wired to the palette placeholder rendered when the container has
   * no children.
   *
   * @param {{name: string}} blockEntry - Palette entry the user selected.
   */
  @action
  pickBlockForContainer(blockEntry) {
    this.wireframe.insertBlock({
      blockName: blockEntry.name,
      targetKey: this.args.blockKey,
      position: "inside",
      targetOutletName: this.args.outletName,
    });
  }

  /**
   * Selects this block. Wired to the empty-drop placeholder's
   * `@onActivate`: clicking the placeholder stops propagation (so the
   * chrome's own `onClick` selection never runs), so we re-select here
   * to keep the inspector pointed at the container / cell being filled.
   */
  @action
  selectSelf() {
    this.#selectThisBlock();
  }

  /**
   * Pins the chrome's outer `<div>` reference for later use (drag
   * image, image-arg measurements, tooltip anchoring) and installs the
   * per-block URL-edit tooltips now that we have the DOM to query.
   *
   * Also announces this element to the editor: a freshly inserted (and
   * auto-selected) block can't be scrolled into view or flashed until its
   * element exists, so the service defers that treatment and we trigger it
   * here, the moment this block's chrome mounts.
   *
   * @param {Element} element - The chrome's outer `<div>`.
   */
  @action
  captureChromeEl(element) {
    this.chromeEl = element;
    this.#setupUrlTooltips();
    this.wireframe.notifyChromeInserted(this.args.blockKey, element);
  }

  /**
   * Starts a span-resize from one of the `DResizeHandles`. Snapshots a stable
   * session for the drag: the effective grid dimensions (so a span clamps to the
   * rendered grid, never growing it), the grid's pixel rect, the sibling
   * occupancy (so a growing edge clamps at the first neighbour), the resolved
   * origin placement, and the ghost element. An auto-placed cell has no concrete
   * origin, so its starting cell is taken from the pointer.
   *
   * @param {string} direction - The handle's compass direction.
   * @param {Object} dragInfo - The `DResizeHandles` drag payload.
   * @returns {void|false}
   */
  @action
  onGridResizeStart(direction, dragInfo) {
    const gridEl = this.getResizeGridElement();
    if (!gridEl) {
      return false;
    }
    const columns = this.slotGridColumns;
    const rows = this.slotGridRows;
    const gridRect = gridEl.getBoundingClientRect();
    const startCell = cellAt(dragInfo.event, gridRect, columns, rows);
    const origin = parseSlotPlacement(this.slotPlacement);
    if (origin.column.start == null) {
      origin.column = { start: startCell.column, end: startCell.column + 1 };
    }
    if (origin.row.start == null) {
      origin.row = { start: startCell.row, end: startCell.row + 1 };
    }
    const ghost = this.getResizeGhost();
    this.#gridResize = {
      origin,
      columns,
      rows,
      gridRect,
      occupied: this.getResizeOccupied(),
      ghost,
      next: null,
    };
    if (ghost) {
      this.#applyGhostStyle(ghost, origin);
      ghost.classList.add("--visible");
    }
  }

  /**
   * Previews the span on each pointer move: maps the pointer to a grid cell and
   * computes the clamped placement (`computeSpanResize` stops a growing edge at
   * the first occupied neighbour and at the rendered grid bounds), then paints
   * the ghost.
   *
   * @param {string} direction - The handle's compass direction.
   * @param {Object} dragInfo - The `DResizeHandles` drag payload.
   * @returns {void}
   */
  @action
  onGridResize(direction, dragInfo) {
    const session = this.#gridResize;
    if (!session) {
      return;
    }
    const cell = cellAt(
      dragInfo.event,
      session.gridRect,
      session.columns,
      session.rows
    );
    const next = computeSpanResize({
      origin: session.origin,
      cell,
      direction,
      columns: session.columns,
      rows: session.rows,
      occupied: session.occupied,
    });
    session.next = next;
    if (session.ghost) {
      this.#applyGhostStyle(session.ghost, next);
    }
  }

  /**
   * Commits the span-resize on release, writing the clamped placement to this
   * slot's own `containerArgs.grid` in place (the cell border grows / shrinks,
   * the inner content stays put). Resize never grows the declared grid — see
   * `GridManipulator#resizeSlot`.
   *
   * @returns {void}
   */
  @action
  onGridResizeEnd() {
    const next = this.#gridResize?.next;
    this.#endGridResize();
    if (next) {
      this.wireframe.gridManipulator.resizeSlot({
        slotKey: this.args.blockKey,
        column: formatTrack(next.column),
        row: formatTrack(next.row),
      });
    }
  }

  /** @returns {void} */
  @action
  onGridResizeCancel() {
    this.#endGridResize();
  }

  #applyGhostStyle(ghost, placement) {
    ghost.style.gridColumn = `${placement.column.start} / ${placement.column.end}`;
    ghost.style.gridRow = `${placement.row.start} / ${placement.row.end}`;
  }

  #endGridResize() {
    this.#gridResize?.ghost?.classList.remove("--visible");
    this.#gridResize = null;
  }

  /**
   * Captures the click only when editor is active. Stops propagation so the
   * host page's own click handlers (links, buttons inside the block) don't
   * fire while the user is editing.
   *
   * Click model:
   *   - Block not selected → first click selects it.
   *   - Block already selected, click landed on an `[data-wf-inline-edit-arg]`
   *     region → start editing that arg (the "click again to edit" gesture).
   *   - Block already selected, click landed elsewhere on the chrome → no-op
   *     (re-selecting the already-selected block is a no-op).
   */
  @action
  onClick(event) {
    if (!this.wireframe.isActive) {
      return;
    }
    // A LOCKED outlet is read-only — swallow the click so nothing inside it can
    // be selected or edited.
    if (this.isReadOnlyOutlet) {
      event.preventDefault();
      event.stopPropagation();
      return;
    }
    event.preventDefault();
    event.stopPropagation();

    // A container that forces its children to one kind (e.g. this block when it
    // declares a single `childBlocks`) renders an "add" affordance carrying the
    // `data-wf-append-child` marker. Clicking it appends a fresh child of that
    // kind and selects it — no selection precondition, since it's an explicit
    // button. Handled BEFORE the `detail === 0` bail below: activating the
    // button by keyboard (Space / Enter) is a legitimate "add" gesture, and
    // synthesized clicks (tests) carry `detail === 0` too.
    if (event.target.closest?.("[data-wf-append-child]")) {
      this.wireframe.appendImplicitChild(this.args.blockKey);
      return;
    }

    // A block arg rendered as a native <button> (e.g. a button-link with
    // no URL set yet) activates on Space / Enter and dispatches a click
    // even while the caret sits in the label's inline editor nested
    // inside it. Such keyboard-synthesized clicks carry `detail === 0`;
    // the select / click-again-to-edit gestures are all pointer-driven,
    // so this click is spurious — bail before it opens the URL editor and
    // steals focus from the inline text edit.
    if (event.detail === 0) {
      return;
    }

    // A tab in a switchable strip (e.g. this block's tabs). The block's own
    // tab button already switched the active panel; here we route SELECTION:
    // a click selects that tab's panel layout, so the inspector targets it
    // (including its `containerArgs.tab.label`) and the drop area is the active
    // panel. Clicking the already-active tab whose panel is already selected
    // starts an inline edit of its label instead (the "click again to edit"
    // gesture) — the active tab carries the `data-wf-container-arg-*` markers,
    // and the DOM hasn't re-rendered yet so `aria-selected` still reflects the
    // pre-click active tab.
    const tabEl = event.target.closest?.("[data-wf-tab-panel-key]");
    if (tabEl) {
      const panelKey = tabEl.dataset.wfTabPanelKey;
      const isActive = tabEl.getAttribute("aria-selected") === "true";
      if (
        isActive &&
        this.wireframe.selectedBlockKey === panelKey &&
        tabEl.dataset.wfContainerArgKey
      ) {
        this.wireframe.inlineEdit.startContainerArg(
          tabEl.dataset.wfContainerArgKey,
          tabEl.dataset.wfContainerArgNamespace,
          tabEl.dataset.wfContainerArgField,
          { coords: { x: event.clientX, y: event.clientY } }
        );
        return;
      }
      this.wireframe.selectBlock({ key: panelKey });
      return;
    }

    // A carousel nav control (prev / next / dot). The carousel's own click
    // handler already paged the track during bubbling; swallow the chrome's
    // selection so paging a slide into view is never mistaken for selecting or
    // deselecting the block — it stays selectable by clicking its body.
    if (event.target.closest?.("[data-wf-carousel-nav]")) {
      return;
    }

    const argEl = event.target.closest?.("[data-block-arg]");
    const argName = argEl?.dataset?.blockArg;
    const kind = argName ? kindForArg(this.metadata, argName) : null;

    // Image args don't have an internal selection model the way text
    // does, so a single click on the rendered image opens the replace
    // / remove menu directly. Selecting the block is a side effect so
    // the inspector tracks the change.
    if (argEl && kind === "image") {
      if (this.wireframe.selectedBlockKey !== this.args.blockKey) {
        this.#selectThisBlock();
      }
      this.#openImageEditMenu(argEl, argName);
      return;
    }

    // Other inline-editable args follow the "click to select, click
    // again to edit" pattern — placing the cursor inside text or
    // anchoring a popover requires the click to be on the already-
    // selected block, otherwise the first click is interpreted as
    // selection.
    if (argEl && this.wireframe.selectedBlockKey === this.args.blockKey) {
      switch (kind) {
        case "rich-text":
          this.wireframe.inlineEdit.start(this.args.blockKey, argName, {
            coords: { x: event.clientX, y: event.clientY },
          });
          return;
        case "icon":
          this.wireframeIconEdit.start({
            blockKey: this.args.blockKey,
            argName,
            anchorEl: argEl,
          });
          return;
        case "url":
          this.wireframeLinkEdit.start({
            blockKey: this.args.blockKey,
            argName,
          });
          // The hover popover registered on this same link element
          // owns the URL-edit UI. Force it open so the user sees the
          // editor surface even if they came in via a click rather
          // than a hover.
          this.#urlTooltips.find((t) => t.trigger === argEl)?.show?.();
          return;
      }
      // No matching kind — fall through to block selection.
    }

    this.#selectThisBlock();
  }

  /**
   * Drop-target gate — rejects drops that would re-insert a block onto its
   * own zones (a no-op anyway) and consults the editor service for outlet-
   * level allowed/denied checks. The modifier filters drags whose `type`
   * isn't `"wf-block"` or `"wf-palette-block"`, so this only fires for
   * our own payloads.
   *
   * Move drags (`wf-block`) consult `canDropAt` against the active drag
   * source; palette inserts (`wf-palette-block`) consult
   * `canInsertBlockAt` against the source's `blockName`.
   */
  @action
  canDropOnThisBlock({ source }) {
    if (source?.type === "wf-palette-block") {
      return this.wireframe.dropAuthority.canInsertBlockAt({
        blockName: source.data?.blockName,
        targetOutletName: this.args.outletName,
      });
    }
    if (source?.data?.blockKey === this.args.blockKey) {
      return false;
    }
    return this.wireframe.dropAuthority.canDropAt({
      targetOutletName: this.args.outletName,
    });
  }

  /**
   * Gate for the chrome-level external file drop. A chrome accepts a
   * dropped file in one of two ways:
   *
   *   - Background fill: the block renders a passive ("background") image
   *     marker, so a body drop replaces that image.
   *   - Slot insert: the chrome is a container slot (stack / row / cell),
   *     so a body drop creates a new image block in the slot, treated like
   *     dropping an image block from the palette.
   *
   * Every other chrome stays inert (no indicator, no drop handling) so
   * PDND walks up to an ancestor that does accept.
   *
   * @param {{input: Object}} payload
   * @returns {boolean}
   */
  @action
  canDropExternalImageFile({ input }) {
    if (this.canDropBackgroundFile()) {
      return true;
    }
    if (this.#isImageDropSlot) {
      // Defer a near-edge drop to the parent container, matching the
      // block-drag path's edge-band behaviour.
      return !this.#ensureExternalDropResolver().shouldDeferToParent(input);
    }
    return false;
  }

  /**
   * Whether the block renders a passive ("background") image marker, gating
   * the background-fill drop path.
   *
   * @returns {boolean}
   */
  @action
  canDropBackgroundFile() {
    return !!this.#passiveImageArgName();
  }

  /**
   * Whether this chrome is a container slot that accepts a dropped file as
   * a new image block (the slot-insert path). Grid surfaces are owned by
   * the grid overlay and leaves defer to their parent, so neither qualifies.
   *
   * @returns {boolean}
   */
  get #isImageDropSlot() {
    const mode = this.containerDropMode;
    return mode === "stack" || mode === "row" || mode === "cell";
  }

  /**
   * Builds (once per drag) the geometry resolver the slot-insert path uses
   * to turn the cursor position into a drop descriptor — the same resolver
   * the `containerDropTarget` modifier uses for block drags.
   *
   * @returns {Object}
   */
  #ensureExternalDropResolver() {
    this.#externalDropResolver ||= createContainerDropResolver({
      wireframe: this.wireframe,
      chromeElement: this.chromeEl,
      containerKey: this.args.blockKey,
      outletName: this.args.outletName,
      mode: this.containerDropMode,
    });
    return this.#externalDropResolver;
  }

  /**
   * Claims the single drag-overlay slot as a file is dragged over this block.
   * A background block claims the passive image-arg overlay (its tint then
   * shows via the coordinator); a container slot claims the slot-insert
   * preview. A foreground image overlay (e.g. the avatar) is a DEEPER external
   * target, so its own claim lands over this one — that's what keeps a single
   * overlay showing, replacing the old foreground/background bookkeeping.
   *
   * @param {{location: {current: {input: Object}}}} payload
   */
  @action
  onExternalImageDragEnter({ location }) {
    this.#claimExternalOverlay(location.current.input);
  }

  /**
   * Re-claims as the cursor moves so the overlay tracks it.
   *
   * @param {{location: {current: {input: Object}}}} payload
   */
  @action
  onExternalImageDrag({ location }) {
    this.#claimExternalOverlay(location.current.input);
  }

  #claimExternalOverlay(input) {
    if (this.canDropBackgroundFile()) {
      this.#releaseDrop = this.wireframeDragOverlay.claimImageArg({
        blockKey: this.args.blockKey,
        argName: this.#passiveImageArgName(),
        isPassive: true,
      });
      return;
    }
    if (this.#isImageDropSlot) {
      this.#releaseDrop = this.wireframeDragOverlay.claimSlotInsert(
        this.#ensureExternalDropResolver().descriptorFor(
          EXTERNAL_IMAGE_DROP_SOURCE,
          input
        )
      );
    }
  }

  @action
  onExternalImageDragLeave() {
    this.#externalDropResolver = null;
    this.#releaseDrop?.();
  }

  /**
   * Routes a file dropped on the block body. For a background block the
   * file fills the passive ("background") image arg through its overlay's
   * own pipeline (progress bar, value write, block selection); for a
   * container slot it creates a new image block at the previewed slot and
   * uploads into it. Per-arg image overlays (e.g. the avatar slot) are
   * deeper external drop targets, so PDND routes drops over them there
   * instead — only body drops reach this handler.
   *
   * @param {{source: {getFiles: () => File[]}}} payload
   */
  @action
  onExternalImageDrop({ source }) {
    this.#externalDropResolver = null;
    if (this.canDropBackgroundFile()) {
      this.#releaseDrop?.();
      const file = source?.getFiles?.()?.[0];
      if (file) {
        this.pendingBackgroundFile = file;
      }
      return;
    }
    if (!this.#isImageDropSlot) {
      return;
    }
    // Per-file MIME isn't readable during the drag, so the preview shows for
    // any file; a non-image release is a clean no-op here.
    const file = firstImageFile(source.getFiles());
    if (!file) {
      this.#releaseDrop?.();
      return;
    }
    this.wireframe.completeExternalImageDrop(file);
  }

  /**
   * Registers a FloatKit tooltip per URL inline-editable arg on this
   * block, anchored to the rendered link element (matched via
   * `[data-block-arg]` + `kindForArg` lookup). The tooltip hosts a
   * `LinkEditPopover` that swaps between a chip and an input mode in
   * place — `data` carries the `(blockKey, argName)` the popover needs
   * to drive its own `linkEdit` session.
   *
   * `hoverGracePeriod` gives the pointer ~120 ms to cross FloatKit's
   * offset gap from the trigger to the popover without dismissing —
   * see the matching listeners in `FloatKitInstance` and the
   * `hoverGrace` modifier in `d-float-body.gjs`.
   *
   * Why this lives in the chrome and not the block templates: the
   * blocks just emit `data-block-arg` (semantic markup); all editor
   * scaffolding — including hover-triggered affordances — lives in
   * admin code.
   */
  #setupUrlTooltips() {
    const meta = this.metadata;
    if (!meta?.args || !this.chromeEl) {
      return;
    }
    const linkEls = this.chromeEl.querySelectorAll(BLOCK_ARG_SELECTOR);
    for (const linkEl of linkEls) {
      const argName = linkEl.dataset.blockArg;
      if (kindForArg(meta, argName) !== "url") {
        continue;
      }
      const instance = this.tooltip.register(linkEl, {
        identifier: "wf-link-edit-popover",
        component: LinkEditPopover,
        interactive: true,
        hoverGracePeriod: 120,
        placement: "right",
        offset: 4,
        // `dTrapTab` autofocuses the popover's first focusable element by
        // default when `trapTab` is on (and `interactive: true` turns it
        // on). On hover-show that pulls focus out of any active inline
        // editor on the same block — e.g. typing in the label PM editor
        // while the URL chip materialises next to it. Tab-trapping is
        // still useful for the edit-mode input, but autofocus is not:
        // `seedInputValue` focuses the URL input directly when the popover
        // swaps into edit mode.
        autofocus: false,
        data: {
          blockKey: this.args.blockKey,
          argName,
        },
      });
      this.#urlTooltips.push(instance);
    }
  }

  /**
   * Opens the FloatKit menu that hosts Replace / Remove actions for a
   * clicked image marker. The menu is mounted as a sibling of the
   * marker (FloatKit handles positioning) and tracks the marker as its
   * anchor; FloatKit re-positions on scroll / resize.
   *
   * Marks this arg as the most recently-touched image arg on the
   * service so a subsequent paste still routes here. Closing the menu
   * is handled by FloatKit's outside-click / Escape contract; the menu
   * component also calls back `data.close()` after Replace / Remove
   * commits.
   *
   * @param {Element} argEl - The clicked `[data-block-arg]` element.
   * @param {string} argName - The image arg name on this block.
   */
  async #openImageEditMenu(argEl, argName) {
    this.wireframe.markImageArgTouched(argName);
    // The `close` callback captures `instance` by reference. At the
    // time the data object is created, `instance` is in the TDZ; by
    // the time the menu's Replace / Remove buttons can fire it the
    // `await` below has resolved and `instance` is assigned.
    let instance;
    const data = {
      blockKey: this.args.blockKey,
      argName,
      close: () => instance?.close(),
    };
    instance = await this.menu.show(argEl, {
      identifier: "wireframe-image-edit-menu",
      component: ImageEditMenu,
      placement: "bottom",
      fallbackPlacements: ["top", "right", "left"],
      maxWidth: 240,
      data,
    });
  }

  /**
   * Selects the wrapped block via the editor service. Extracted from
   * the per-kind dispatch in `onClick` so the image-arg single-click
   * path can re-use it without duplicating the data payload.
   */
  #selectThisBlock() {
    this.wireframe.selectBlock({
      key: this.args.blockKey,
      name: this.args.blockName,
      id: this.args.blockId,
      args: this.args.blockArgs,
      containerArgs: this.args.containerArgs,
      conditions: this.args.conditions,
      outletArgs: this.args.outletArgs,
      outletName: this.args.outletName,
      metadata: this.metadata,
    });
  }

  /**
   * The name of this block's passive ("background") image arg, read from
   * the rendered DOM marker (`[data-drop-passive]`), or `null` when the
   * block has none. Runtime DOM introspection mirroring `getImageMarkerEl`;
   * the marker stays in the DOM even while collapsed, so this resolves in
   * every selection / fill state.
   *
   * @returns {string|null}
   */
  #passiveImageArgName() {
    return (
      this.chromeEl
        ?.querySelector("[data-drop-passive]")
        ?.getAttribute(BLOCK_ARG_ATTR) ?? null
    );
  }

  <template>
    {{#if this.wireframe.isActive}}
      {{! Outer wrapper hosts the sibling drop zones (before/after) for
        stack / row layouts and the bordered chrome frame in between.
        Grid cell occupants skip the sibling drop zones — their
        placement is by cell coordinate, applied via the `@style`
        forwarded from the parent layout. In active editor mode the
        chrome IS the rendered outermost element (the curried child the
        layout sees), so the parent's placement style needs to land here
        rather than on the inner `WrappedBlockLayout` div. }}
      <div
        class={{dConcatClass
          "wireframe-block-chrome-wrapper"
          (if this.isGridCell "--in-grid-cell")
          (if @isGhost "--ghost")
          (if @isError "--error")
          (if (eq this.parentLayoutAxis "horizontal") "--axis-horizontal")
          (if this.isForceExpanded "--force-expanded")
        }}
        style={{@style}}
      >
        <div
          class={{dConcatClass
            "wireframe-block-chrome"
            (if this.isSelected "--selected")
            (if this.isContainer "--container")
            (if this.isOutletRoot "--outlet-root")
            (if this.isReadOnlyOutlet "--read-only")
            (if this.isEmptyContainer "--empty-container")
            (if this.hasGridOverlap "--overlapping")
            (if this.isOutOfBounds "--out-of-bounds")
            (if this.hasUnresolvedImageArg "--unresolved-image")
            (if @isGhost "--ghost")
            (if @isError "--error")
            (if this.isEmptyCell "--cell")
            (if this.isPart "--part")
          }}
          data-wf-block-name={{@blockName}}
          data-wf-block-key={{@blockKey}}
          data-wf-empty={{this.isEmptyContainer}}
          {{didInsert this.captureChromeEl}}
          {{containerDropTarget
            containerKey=@blockKey
            outletName=@outletName
            mode=this.containerDropMode
          }}
          {{! Makes a container's proxy children draggable so they can be
            reordered (e.g. a tabs strip's buttons, which carry the
            drop-child-key marker); a no-op for blocks that render none.
            Re-scans on each structural edit. }}
          {{proxyDragSources
            outletName=@outletName
            version=this.wireframe.structuralVersion
          }}
          {{! Chrome-level external file drop. One target per chrome handles
            both paths: filling a passive background image arg, and creating a
            new image block when this chrome is a container slot. Per-image-arg
            overlays (the avatar slot) are deeper external drop targets, so
            PDND sends drops over them there instead. The canDrop gate keeps
            this inert for blocks that are neither. }}
          {{dDragAndDropExternalTarget
            accepts="files"
            indicator=false
            canDrop=this.canDropExternalImageFile
            onDragEnter=this.onExternalImageDragEnter
            onDrag=this.onExternalImageDrag
            onDragLeave=this.onExternalImageDragLeave
            onDrop=this.onExternalImageDrop
          }}
          {{on "click" this.onClick}}
          role="button"
          tabindex="0"
        >
          {{! A read-only (LOCKED) outlet shows no toolbar — no drag handle, no
            actions — so its programmatic layout can't be edited. For the outlet
            root the bar is the always-on identity badge above the region (the
            handle carries the cube icon, name, and status chip); for other
            blocks it reveals on hover / selection. The outlet status args drive
            the handle's chip. }}
          {{#unless this.isReadOnlyOutlet}}
            <BlockToolbar
              @blockKey={{@blockKey}}
              @outletName={{@outletName}}
              @displayName={{this.displayName}}
              @displayTitle={{this.childTooltip}}
              @displayChip={{this.childOrdinal}}
              @moveAxis={{this.siblingMoveAxis}}
              @isOutletRoot={{this.isOutletRoot}}
              @outletState={{this.outletState}}
              @isOutletEditing={{this.isOutletEditing}}
              @showOutletStatus={{this.showOutletStatus}}
              @chromeEl={{this.chromeEl}}
              @isSelected={{this.isSelected}}
              @canFillImage={{this.imageCanFillBlock}}
              @canResetImage={{this.imageIsResized}}
              @onFillImage={{this.fillImageToBlock}}
              @onResetImage={{this.resetImageToNaturalSize}}
            />
          {{/unless}}

          {{! Overlap / out-of-bounds warning badge — only visible when
            this cell's rectangle intersects a sibling or runs past the
            grid's edge. Loud on purpose: a tinted background alone is
            too easy to miss. }}
          {{#if this.isOutOfBounds}}
            <span
              class="wireframe-block-chrome__overlap-badge"
              title={{i18n "wireframe.canvas.out_of_bounds_warning"}}
            >
              {{dIcon "triangle-exclamation"}}
              <span>{{i18n "wireframe.canvas.out_of_bounds_label"}}</span>
            </span>
          {{else if this.hasGridOverlap}}
            <span
              class="wireframe-block-chrome__overlap-badge"
              title={{i18n "wireframe.canvas.overlap_warning"}}
            >
              {{dIcon "triangle-exclamation"}}
              <span>{{i18n "wireframe.canvas.overlap_label"}}</span>
            </span>
          {{else if this.hasUnresolvedImageArg}}
            <span
              class="wireframe-block-chrome__overlap-badge wireframe-block-chrome__overlap-badge--info"
              title={{i18n "wireframe.canvas.unresolved_image_warning"}}
            >
              {{dIcon "triangle-exclamation"}}
              <span>{{i18n "wireframe.canvas.unresolved_image_label"}}</span>
            </span>
          {{/if}}

          {{#if this.isEmptyCell}}
            <div
              class="wireframe-block-chrome__content"
              style={{this.contentStyle}}
            >
              <EditorEmptyDropPlaceholder
                @hint={{i18n "wireframe.canvas.empty_hint"}}
                @palette={{this.palette}}
                @onActivate={{this.selectSelf}}
                @onPick={{this.pickBlockForCell}}
              />
            </div>
          {{else if this.isGridCell}}
            {{! Grid cells: the chrome always fills the cell rectangle
              (border traces the full cell), and a single-cell sub-grid
              inside positions the wrapped block per the user's
              `align` / `justify` choice. }}
            <div
              class="wireframe-block-chrome__content"
              style={{this.contentStyle}}
            >
              <@WrappedComponent />
            </div>
          {{else}}
            <@WrappedComponent />
          {{/if}}

          {{! Per-arg overlays painted on top of the rendered block —
            one per image arg, empty or filled. Each positions itself
            over its arg's marker via JS-computed bounding rects (see
            `image-arg-overlay.gjs`): an in-place "add image" affordance
            when empty, an invisible drop-to-replace target when filled.
            Keyed on emptiness so a fill / clear remounts the overlay. }}
          {{#each this.imageArgEntries key="key" as |imageArg|}}
            <ImageArgOverlay
              @blockKey={{@blockKey}}
              @argName={{imageArg.name}}
              @argDef={{imageArg.def}}
              @isEmpty={{imageArg.isEmpty}}
              @getChromeEl={{this.getChromeEl}}
              @pendingFile={{this.pendingBackgroundFile}}
            />
          {{/each}}

          {{#if this.showsGridOverlay}}
            <GridOverlay @gridKey={{@blockKey}} @outletName={{@outletName}} />
          {{/if}}

          {{#if this.isGridCell}}
            {{! Edge bars + corner nubs for span-resize. Each handle hands its
              compass direction back through the resize callbacks; edges move one
              axis, corners both. The bar/nub language is deliberately distinct
              from the image block's round resize dots so the two gestures are
              never confused. Always rendered for a grid cell; the SCSS reveals
              them on hover or when the cell is selected (matching the empty-cell
              merge handles), so pointer-events stay off until then. }}
            <DResizeHandles
              @handleClass="wireframe-block-chrome__resize-handle"
              @directions={{this.gridResizeDirections}}
              @onResizeStart={{this.onGridResizeStart}}
              @onResize={{this.onGridResize}}
              @onResizeEnd={{this.onGridResizeEnd}}
              @onResizeCancel={{this.onGridResizeCancel}}
              @draggingClass="--dragging"
            />
          {{/if}}

          {{#if this.showsImageResizeHandle}}
            <ImageResizeOverlay
              @blockKey={{@blockKey}}
              @argName={{this.resizableImageArg.name}}
              @getChromeEl={{this.getChromeEl}}
              @getMarkerEl={{this.getImageMarkerEl}}
              @aspectRatio={{this.imageResizeAspectRatio}}
              @onPreview={{this.previewImageResize}}
              @onCommit={{this.commitImageResize}}
            />
          {{/if}}

          {{#if this.isEmptyContainer}}
            <EditorEmptyDropPlaceholder
              @hint={{this.emptyHint}}
              @palette={{this.palette}}
              @onActivate={{this.selectSelf}}
              @onPick={{this.pickBlockForContainer}}
            />
          {{/if}}
        </div>
      </div>
    {{else}}
      <@WrappedComponent />
    {{/if}}
  </template>
}
