// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { getBlockDisplayMetadata } from "discourse/lib/blocks/-internals/display-metadata";
import { and, eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import { i18n } from "discourse-i18n";
// `grid-math` is in the universal bundle (its `parsePlacement` is
// called by the live-page `wf-layout.gjs`); this chrome is admin-only.
// Cross-bundle imports use absolute addon paths.
import {
  parsePlacement,
  placementsOverlap,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";
import { entryHasEmptyImageUploadArgs } from "../../lib/empty-image-upload";
import { kindForArg } from "../../lib/kind-for-arg";
import { entryKey } from "../../lib/mutate-layout";
import containerDropTarget from "../../modifiers/container-drop-target";
import gridTileDrag from "../../modifiers/grid-tile-drag";
import LinkEditPopover from "../link-edit-popover";
import BlockToolbar from "./block-toolbar";
import EmptyCellPlaceholder from "./empty-cell-placeholder";
import EmptyImageState from "./empty-image-state";
import GridOverlay from "./grid-overlay";

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
 *   - The chrome itself is NOT draggable. The `.wireframe-block-handle`
 *     corner badge IS the drag source.
 *   - The handle is rendered always; CSS hides it until the chrome is
 *     hovered or selected. That way users grab it with one gesture, not
 *     two.
 *   - Drop zones (before/after siblings, optional inside-container) are
 *     siblings of the wrapped component within the chrome. They occupy
 *     real layout space (4px) at all times while the editor is active so
 *     hit-testing is reliable from the very first dragenter.
 */
export default class BlockChrome extends Component {
  @service blocks;
  @service tooltip;
  @service wireframe;

  /**
   * Whether this slot is currently showing its palette picker
   * popover. Stored on the chrome instance (rather than at a higher
   * scope) because the chrome IS the slot in this model — each slot
   * gets its own chrome, each picker opens / closes against the
   * chrome that owns it. Unprefixed because the template reads it
   * via `this.pickingSlot`.
   */
  @tracked pickingSlot = false;
  acceptedDragKinds = ["wf-block", "wf-palette-block"];

  /**
   * Returns the chrome element ref for use as a drag image. Passed as a
   * getter (not a value) to the drag-source modifier so it resolves at
   * dragstart, not at modifier setup time when the ref is still null.
   *
   * @returns {Element|null}
   */
  getChromeEl = () => this._chromeEl;
  /**
   * Locates the parent grid layout's grid `<div>` element so the
   * resize modifier can measure cell sizes. Walks up from this chrome's
   * own element through the DOM until it finds the grid container.
   *
   * @returns {Element|null}
   */
  getResizeGridElement = () => {
    if (!this._chromeEl) {
      return null;
    }
    return this._chromeEl.closest(".wf-layout--grid");
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
   * Reference to the chrome's outer `<div>`, set on insert. Used as the
   * drag-source's drag image so the browser shows a translucent copy of
   * the actual block being dragged instead of the tiny handle badge
   * (the default when no `dragImage` is supplied). Tracked so the
   * drag-source modifier re-runs once the ref is captured (it installs
   * before the chrome div's `didInsert` fires, otherwise capturing a
   * stale `null`).
   */
  @tracked _chromeEl = null;

  /**
   * Registered URL-edit tooltips for this block. Cleaned up in
   * `willDestroy`. Hover bridging between the link trigger and the
   * floating chip is handled by float-kit via `hoverGracePeriod`, so
   * the chrome doesn't own any extra listener teardown.
   *
   * @type {any[]}
   */
  _urlTooltips = [];

  willDestroy() {
    super.willDestroy(...arguments);
    for (const instance of this._urlTooltips) {
      instance.destroy?.();
    }
    this._urlTooltips.length = 0;
  }

  /**
   * Block metadata (description, namespace, isContainer, args schema, etc.)
   * for the wrapped block, or `null` if the registry has no entry for this
   * block name.
   *
   * `@cached` memoises the lookup per component instance. A future Phase
   * could promote this to a shared service-level cache to avoid every
   * rendered block walking the registry on first access.
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
    const entry = this.wireframe._findEntryAndOutletSync(
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
    if (this.args.blockName !== "wf:layout") {
      return false;
    }
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const entry = this.wireframe._findEntryAndOutletSync(
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
      this.args.blockName === "wf:layout" &&
      this.wireframe.isForceExpanded(this.args.blockKey)
    );
  }

  /**
   * Resolves the drop-mode the `containerDropTarget` modifier should
   * use for this chrome. Returns `null` for non-container blocks (the
   * modifier is a no-op on them — leaf blocks never act as drop
   * targets directly; their parent container handles it).
   *
   * For `wf:layout` containers we read `args.mode` (live entry, falls
   * back to the curry snapshot at chrome creation time). For other
   * container blocks (e.g. `wf:columns`) we default to `"stack"`
   * since their children stack vertically.
   *
   * @returns {"stack"|"row"|"grid"|null}
   */
  get containerDropMode() {
    if (this.isSlot) {
      return "slot";
    }
    if (!this.isContainer) {
      // Leaves in a parent grid still need to BE a drop target so
      // the grid overlay's swap / shift dispatch has an element-
      // level landing surface. Stack / row leaves don't — their
      // parent container handles drops near them.
      return this.isGridCell ? "grid-cell-leaf" : null;
    }
    if (this.args.blockName !== "wf:layout") {
      return "stack";
    }
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const entry = this.wireframe._findEntryAndOutletSync(
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
   * Columns count of the parent grid layout. Drives the resize
   * modifier's snap math.
   *
   * @returns {number}
   */
  get slotGridColumns() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const grid = this.wireframe._findEntryParent(this.args.blockKey);
    return Number(grid?.args?.columns ?? 6);
  }

  /** @returns {number} */
  get slotGridRows() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const grid = this.wireframe._findEntryParent(this.args.blockKey);
    return Number(grid?.args?.rows ?? 2);
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
      this.wireframe._findEntryAndOutletSync(this.args.blockKey)?.entry
        ?.containerArgs
    );
    if (myPlacement.column.start == null || myPlacement.row.start == null) {
      return false;
    }
    const grid = this.wireframe._findEntryParent(this.args.blockKey);
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
    const grid = this.wireframe._findEntryParent(this.args.blockKey);
    if (!grid) {
      return false;
    }
    const maxColumns = Number(grid.args?.columns ?? 6);
    const maxRows = Number(grid.args?.rows ?? 2);
    const placement = parsePlacement(
      this.wireframe._findEntryAndOutletSync(this.args.blockKey)?.entry
        ?.containerArgs
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
   * Whether to render the before/after sibling drop zones around this
   * chrome. In a stack/row layout they let authors drop blocks
   * adjacent to existing siblings; inside a grid cell there's no
   * "before/after" — placement is by cell coordinate — so the zones
   * are meaningless and (because they take real flow space) actively
   * misalign the chrome with the grid cell. Skip them.
   *
   * @returns {boolean}
   */
  get showsSiblingDropZones() {
    return !this.isGridCell && !this.args.isGhost;
  }

  /**
   * The layout axis of this block's parent — `"horizontal"` for a
   * `wf:layout` in row mode, `"vertical"` for stack mode (the default),
   * `null` otherwise (outlet root, grid slot, non-layout container).
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
    const parent = this.wireframe._findEntryParent(this.args.blockKey);
    if (!parent) {
      return null;
    }
    if (this.wireframe._blockNameOf(parent) !== "wf:layout") {
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
    const entry = this.wireframe._findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    return !entry?.children?.length;
  }

  /**
   * `true` when the wrapped block declares one or more `image-upload` args
   * AND none of them currently hold an uploaded image. Drives the canvas-
   * only empty-state card so blocks like `wf:image` don't render either a
   * giant placeholder graphic or an invisible nothing while the author
   * hasn't picked an image yet. Block templates stay agnostic — they keep
   * rendering nothing for empty image args; the chrome shows the affordance
   * around that void.
   *
   * @returns {boolean}
   */
  get hasEmptyImageUploadArgs() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const entry = this.wireframe._findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    return entryHasEmptyImageUploadArgs(this.metadata?.args, entry?.args);
  }

  /** @returns {string} */
  get displayName() {
    return this.metadata?.shortName ?? this.args.blockName;
  }

  /**
   * `wf:slot` entries are template-defined drop targets. The chrome
   * wraps them like any other block (selection, drag, resize via the
   * existing grid handle), but the inner render area becomes a
   * "Pick a block" placeholder instead of the slot's no-op template,
   * and drops route through `fillSlot` / `moveBlockIntoSlot` so the
   * slot is REPLACED by content rather than inserted-as-sibling.
   *
   * @returns {boolean}
   */
  get isSlot() {
    return this.args.blockName === "wf:slot";
  }

  /**
   * Compact palette for the slot picker popover — same shape the
   * grid overlay uses for its auto-empty-cell picker. The two are
   * intentionally identical in vocabulary; the only difference is
   * where the placeholder is anchored.
   */
  @cached
  get slotPalette() {
    return this.blocks
      .listBlocksWithMetadata()
      .map(({ name, component }) => {
        const display = getBlockDisplayMetadata(component) ?? {};
        return {
          name,
          displayName: display.displayName,
          icon: display.icon,
          paletteHidden: display.paletteHidden === true,
        };
      })
      .filter((row) => !row.paletteHidden)
      .sort((a, b) => a.displayName.localeCompare(b.displayName));
  }

  @action
  openSlotPicker() {
    this.pickingSlot = true;
  }

  @action
  closeSlotPicker() {
    this.pickingSlot = false;
  }

  @action
  pickBlockForSlot(blockEntry) {
    this.wireframe.fillSlot({
      slotKey: this.args.blockKey,
      blockName: blockEntry.name,
    });
    this.pickingSlot = false;
  }

  @action
  captureChromeEl(element) {
    this._chromeEl = element;
    this._setupUrlTooltips();
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
  _setupUrlTooltips() {
    const meta = this.metadata;
    if (!meta?.args || !this._chromeEl) {
      return;
    }
    const linkEls = this._chromeEl.querySelectorAll("[data-block-arg]");
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
      this._urlTooltips.push(instance);
    }
  }

  /**
   * Routes the resize modifier's commit back to THIS slot's own args.
   * The resize handle lives on the slot wrapper (transparent path), so
   * commits update the slot's column / row in place — the cell border
   * grows / shrinks but the inner content stays put.
   */
  @action
  commitSelfResize(placement) {
    this.wireframe.setSlotPlacement({
      slotKey: this.args.blockKey,
      column: placement.column,
      row: placement.row,
    });
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
    event.preventDefault();
    event.stopPropagation();

    const argEl = event.target.closest?.("[data-block-arg]");
    if (argEl && this.wireframe.selectedBlockKey === this.args.blockKey) {
      const argName = argEl.dataset.blockArg;
      const kind = kindForArg(this.metadata, argName);
      switch (kind) {
        case "rich-text":
          this.wireframe.inlineEdit.start(this.args.blockKey, argName, {
            coords: { x: event.clientX, y: event.clientY },
          });
          return;
        case "icon":
          this.wireframe.iconEdit.start({
            blockKey: this.args.blockKey,
            argName,
            anchorEl: argEl,
          });
          return;
        case "url":
          this.wireframe.linkEdit.start({
            blockKey: this.args.blockKey,
            argName,
          });
          // The hover popover registered on this same link element
          // owns the URL-edit UI. Force it open so the user sees the
          // editor surface even if they came in via a click rather
          // than a hover.
          this._urlTooltips.find((t) => t.trigger === argEl)?.show?.();
          return;
      }
      // No matching kind — fall through to block selection.
    }

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
   * Whether a given before/after/inside drop zone for *this* block is
   * currently active (cursor hovering over it during a drag). Drives the
   * `--active` class so the user sees where the drop will land.
   */
  @action
  isDropZoneActive(position) {
    const t = this.wireframe.activeDropTarget;
    return (
      t?.targetKey === this.args.blockKey &&
      t?.position === position &&
      t?.outletName === this.args.outletName
    );
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
      return this.wireframe.canInsertBlockAt({
        blockName: source.data?.blockName,
        targetOutletName: this.args.outletName,
      });
    }
    if (source?.data?.blockKey === this.args.blockKey) {
      return false;
    }
    return this.wireframe.canDropAt({
      targetOutletName: this.args.outletName,
    });
  }

  /**
   * Adapts the source modifier's `{source}` drag-start payload into
   * the shape `wireframe.startDrag` expects (a flat
   * `{blockKey, outletName}`). The data was attached at the
   * `dDragAndDropSource` call site as `(hash blockKey=… outletName=…)`
   * and exposed back to us under `source.data` (with `source.type`
   * carrying the discriminator string).
   */
  @action
  handleDragStart({ source }) {
    this.wireframe.startDrag(source.data);
  }

  /**
   * Forwards the drop-target's `position` straight to the service so the
   * canvas can highlight the matching zone. The core modifier passes
   * `position` in the callback payload (lifted from the modifier's own
   * `position` arg) — we do NOT read `event.currentTarget.dataset`,
   * because by the time `dragLeave` fires from inside its 10ms deferred
   * clear the browser has already nulled out `event.currentTarget`.
   */
  @action
  handleZoneDragEnter({ position }) {
    this.wireframe.setActiveDropTarget({
      targetKey: this.args.blockKey,
      position,
      outletName: this.args.outletName,
    });
  }

  @action
  handleZoneDragLeave({ position }) {
    this.wireframe.clearActiveDropTarget({
      targetKey: this.args.blockKey,
      position,
    });
  }

  /**
   * Deletes the block this chrome wraps. Wired to the trash button on
   * the handle for selected blocks; the inspector's recovery banner
   * uses the same service method.
   */
  @action
  deleteBlock(event) {
    event.preventDefault();
    event.stopPropagation();
    this.wireframe.removeBlock(this.args.blockKey);
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
            (if this.isEmptyContainer "--empty-container")
            (if this.hasGridOverlap "--overlapping")
            (if this.isOutOfBounds "--out-of-bounds")
            (if @isGhost "--ghost")
            (if @isError "--error")
            (if this.isSlot "--slot")
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
          {{on "click" this.onClick}}
          role="button"
          tabindex="0"
        >
          {{#if this.isSelected}}
            <BlockToolbar @blockKey={{@blockKey}} />
          {{/if}}

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
          {{/if}}

          {{! The handle is the ONLY drag source. Always rendered (CSS hides
            it until the chrome is hovered) so the modifier's
            registration is stable across hover transitions. When selected,
            the floating toolbar (above) takes over quick-action duty;
            the handle stays as the drag affordance only.

            `dragImage` is the chrome's outer div — the browser shows a
            translucent copy of the actual block during the drag instead
            of the tiny handle badge (the default). }}
          <span
            class="wireframe-block-handle"
            title={{i18n "wireframe.canvas.drag_handle_title"}}
            {{dDragAndDropSource
              type="wf-block"
              data=(hash blockKey=@blockKey outletName=@outletName)
              dragPreview=this._chromeEl
              onDragStart=this.handleDragStart
              onDrop=this.wireframe.endDrag
            }}
          >
            {{dIcon "grip-lines"}}
            <span>{{this.displayName}}</span>
          </span>

          {{#if this.isSlot}}
            <div
              class="wireframe-block-chrome__content"
              style={{this.contentStyle}}
            >
              <EmptyCellPlaceholder
                @palette={{this.slotPalette}}
                @isOpen={{this.pickingSlot}}
                @onOpen={{this.openSlotPicker}}
                @onClose={{this.closeSlotPicker}}
                @onPick={{this.pickBlockForSlot}}
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
              {{#if this.hasEmptyImageUploadArgs}}
                <EmptyImageState />
              {{else}}
                <@WrappedComponent />
              {{/if}}
            </div>
          {{else if this.hasEmptyImageUploadArgs}}
            <EmptyImageState />
          {{else}}
            <@WrappedComponent />
          {{/if}}

          {{#if this.showsGridOverlay}}
            <GridOverlay @gridKey={{@blockKey}} @outletName={{@outletName}} />
          {{/if}}

          {{#if (and this.isGridCell this.isSelected)}}
            <span
              class="wireframe-block-chrome__resize-handle"
              title={{i18n "wireframe.canvas.resize_handle_title"}}
              aria-hidden="true"
              {{gridTileDrag
                this.getResizeGridElement
                this.slotPlacement
                this.slotGridColumns
                this.slotGridRows
                this.getResizeGhost
                this.commitSelfResize
              }}
            ></span>
          {{/if}}

          {{#if this.isEmptyContainer}}
            <span class="wireframe-block-chrome__empty-hint">
              {{i18n "wireframe.canvas.empty_container_hint"}}
            </span>
          {{/if}}
        </div>
      </div>
    {{else}}
      <@WrappedComponent />
    {{/if}}
  </template>
}
