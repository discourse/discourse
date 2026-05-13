// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";
import { parseSlotPlacement, placementsOverlap } from "../../lib/grid-math";
import { entryKey } from "../../lib/mutate-layout";
import gridTileDrag from "../../modifiers/grid-tile-drag";
import BlockToolbar from "./block-toolbar";
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
 *   - The chrome itself is NOT draggable. The `.visual-editor-block-handle`
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
  @service visualEditor;

  acceptedDragKinds = ["ve-block", "ve-palette-block"];

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
    return this._chromeEl.closest(".ve-layout--grid");
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
    return grid?.querySelector(".visual-editor-grid-ghost") ?? null;
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
    return this.visualEditor.isBlockSelected(this.args.blockKey);
  }

  /** @returns {boolean} */
  get isContainer() {
    return this.metadata?.isContainer ?? false;
  }

  /**
   * Whether the wrapped block is marked `transparent` (e.g. `ve:slot`).
   * Transparent blocks skip the standard chrome decoration (border /
   * handle / drop zones / toolbar) but the chrome STILL renders a
   * positioned wrapper around the inner component. The wrapper
   * carries inline grid styles read from the block's args so the
   * placement still anchors to the chrome wrapper — which is what
   * CSS Grid sees as the direct child of the parent container.
   *
   * Without this wrapper, Glimmer's component-boundary semantics
   * combined with the chrome curry chain made `grid-column` /
   * `grid-row` styles on the slot's inner `<div>` invisible to the
   * parent grid (the chrome's mere presence as a wrapping component
   * shifted the slot's div out of "direct child" position for the
   * grid).
   *
   * @returns {boolean}
   */
  get isTransparent() {
    return this.metadata?.transparent === true;
  }

  /**
   * Inline grid placement style for the transparent chrome wrapper.
   * Reads `column` / `row` / `align` / `justify` from the LIVE entry
   * args via the visualEditor service. The curried `@blockArgs` arg
   * is a snapshot taken at chrome-curry time and does NOT update
   * reactively when `setSlotPlacement` writes new placement — so the
   * resize / move pointer commits would update the slot data but
   * never re-render the wrapper. Reading through the service opens
   * a tracked dep on `structuralVersion` (bumped by every
   * placement commit) so the wrapper re-paints on the next render.
   *
   * Defaults to `auto` for any arg the block doesn't carry, so non-
   * grid contexts (a transparent block inside a stack / row) ignore
   * these styles harmlessly.
   *
   * @returns {ReturnType<typeof trustHTML>}
   */
  get transparentWrapperStyle() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.visualEditor.structuralVersion;
    const entry = this.visualEditor._findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    const args = entry?.args ?? this.args.blockArgs ?? {};
    const column = args.column ?? "auto";
    const row = args.row ?? "auto";
    const alignSelf = args.align ?? "stretch";
    const justifySelf = args.justify ?? "stretch";
    return trustHTML(
      `grid-column: ${column}; grid-row: ${row}; ` +
        `align-self: ${alignSelf}; justify-self: ${justifySelf};`
    );
  }

  /**
   * Whether the wrapped block is a `ve:layout` in `grid` mode (the
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
    if (this.args.blockName !== "ve:layout") {
      return false;
    }
    // eslint-disable-next-line no-unused-vars
    const _v = this.visualEditor.structuralVersion;
    const entry = this.visualEditor._findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    const mode = entry?.args?.mode ?? this.args.blockArgs?.mode ?? "stack";
    return mode === "grid" || mode === "free-grid";
  }

  /**
   * Whether to mount the grid overlay (cell placeholders + drag ghost).
   * Always mounts while the editor is active and the block is a
   * `ve:layout` in grid mode — gating on selection meant the cells
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
    return this.isGridLayout;
  }

  /**
   * Whether this block sits directly inside a `ve:slot` (which only
   * exists inside a `ve:layout` in grid mode). Drives the resize-handle
   * affordance — the inner block's chrome is the visible "cell", so
   * authors resize from there.
   *
   * @returns {boolean}
   */
  get isInFreeGridSlot() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.visualEditor.structuralVersion;
    const parent = this.visualEditor._findEntryParent(this.args.blockKey);
    if (!parent) {
      return false;
    }
    // `parent.block` is either a string ref (legacy / theme blocks) or a
    // class reference (decorated blocks). For decorated `VESlot`, the
    // class's `.name` is `"VESlot"`, NOT `"ve:slot"` — so we have to ask
    // the service to resolve the block's registered name via metadata
    // lookup. Falling back to `.name` was the bug that made every chrome
    // inside a slot fail the check, leaving the chrome's margin/padding
    // applied and the cell looking misaligned.
    return this.visualEditor._blockNameOf(parent) === "ve:slot";
  }

  /**
   * The slot's own current placement (`{column, row}`), read live via
   * the service. Used by the resize modifier mounted on the slot
   * wrapper itself (transparent path) — the slot IS the cell, so its
   * own column / row are what we resize.
   *
   * @returns {{column: string, row: string}}
   */
  get slotPlacement() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.visualEditor.structuralVersion;
    const entry = this.visualEditor._findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    return {
      column: entry?.args?.column ?? "auto",
      row: entry?.args?.row ?? "auto",
    };
  }

  /**
   * Columns count of the grid layout containing this slot.
   * (`ve:slot`'s parent is always the `ve:layout`.) Drives the resize
   * modifier's snap math.
   *
   * @returns {number}
   */
  get slotGridColumns() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.visualEditor.structuralVersion;
    const grid = this.visualEditor._findEntryParent(this.args.blockKey);
    return Number(grid?.args?.columns ?? 6);
  }

  /** @returns {number} */
  get slotGridRows() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.visualEditor.structuralVersion;
    const grid = this.visualEditor._findEntryParent(this.args.blockKey);
    return Number(grid?.args?.rows ?? 2);
  }

  /**
   * Whether this slot's cell rectangle overlaps a sibling slot in the
   * same grid layout. Drives the `--overlapping` class on the
   * slot wrapper (transparent path). Only checked for the slot's own
   * chrome — inner-block chromes inside a slot have their decoration
   * suppressed via SCSS, so they don't need their own overlap state.
   *
   * Auto-placed slots are excluded (CSS auto-flow handles them).
   *
   * @returns {boolean}
   */
  get hasGridOverlap() {
    if (!this.isTransparent || this.args.blockName !== "ve:slot") {
      return false;
    }
    // eslint-disable-next-line no-unused-vars
    const _v = this.visualEditor.structuralVersion;
    const entry = this.visualEditor._findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    if (!entry?.args) {
      return false;
    }
    const grid = this.visualEditor._findEntryParent(this.args.blockKey);
    if (!grid?.children?.length) {
      return false;
    }
    const myPlacement = parseSlotPlacement(entry.args);
    if (myPlacement.column.start == null || myPlacement.row.start == null) {
      return false;
    }
    for (const sibling of grid.children) {
      if (entryKey(sibling) === this.args.blockKey) {
        continue;
      }
      const theirPlacement = parseSlotPlacement(sibling.args ?? {});
      if (placementsOverlap(myPlacement, theirPlacement)) {
        return true;
      }
    }
    return false;
  }

  /**
   * Whether the block INSIDE this slot is the active selection. Drives
   * the slot wrapper's `--selected` styling (solid border + visible
   * resize handle). Authors click the heading inside a cell; the cell
   * outline lights up because of THIS getter, not because the slot
   * itself is selected.
   *
   * @returns {boolean}
   */
  get isInnerSelected() {
    if (!this.isTransparent || this.args.blockName !== "ve:slot") {
      return false;
    }
    // eslint-disable-next-line no-unused-vars
    const _v = this.visualEditor.structuralVersion;
    const entry = this.visualEditor._findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    if (!entry?.children?.length) {
      return this.isSelected;
    }
    const innerKey = entryKey(entry.children[0]);
    return (
      this.isSelected ||
      (innerKey && this.visualEditor.isBlockSelected(innerKey))
    );
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
    return this.isContainer && !this.isGridLayout;
  }

  /**
   * Whether to render the before/after sibling drop zones around this
   * chrome. In a stack/row/auto-grid layout they let authors drop
   * blocks adjacent to existing siblings; inside a grid slot
   * there's no "before/after" — placement is by cell coordinate — so
   * the zones are meaningless and (because they take real flow space)
   * actively misalign the chrome with the grid cell. Skip them.
   *
   * @returns {boolean}
   */
  get showsSiblingDropZones() {
    return !this.isInFreeGridSlot;
  }

  /**
   * Whether the wrapped block is a container with no children. Containers
   * normally render via `{{#each @children}}` so an empty one produces
   * zero DOM and the inside-drop zone collapses to nothing visible.
   * When this flips true, the template renders a labelled empty-state
   * hint so authors can see (and aim at) the drop target.
   *
   * Resolved live from the visual-editor service rather than via a
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
    const _v = this.visualEditor.structuralVersion;
    const entry = this.visualEditor._findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    return !entry?.children?.length;
  }

  /** @returns {string} */
  get displayName() {
    return this.metadata?.shortName ?? this.args.blockName;
  }

  @action
  captureChromeEl(element) {
    this._chromeEl = element;
  }

  /**
   * Routes the resize modifier's commit back to THIS slot's own args.
   * The resize handle lives on the slot wrapper (transparent path), so
   * commits update the slot's column / row in place — the cell border
   * grows / shrinks but the inner content stays put.
   */
  @action
  commitSelfResize(placement) {
    this.visualEditor.setSlotPlacement({
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
   * For transparent slots, the click routes to the slot's INNER block
   * instead — the slot is internal plumbing; the user wants to inspect
   * and edit the heading / image / etc. they actually see in the cell.
   */
  @action
  onClick(event) {
    if (!this.visualEditor.isActive) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    if (this.isTransparent && this.args.blockName === "ve:slot") {
      const entry = this.visualEditor._findEntryAndOutletSync(
        this.args.blockKey
      )?.entry;
      const inner = entry?.children?.[0];
      if (inner) {
        const innerKey = entryKey(inner);
        const innerName = this.visualEditor._blockNameOf(inner);
        this.visualEditor.selectBlock({
          key: innerKey,
          name: innerName,
          args: inner.args,
          outletName: this.args.outletName,
          conditions: inner.conditions ?? null,
          metadata: null,
        });
        return;
      }
    }
    this.visualEditor.selectBlock({
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
    const t = this.visualEditor.activeDropTarget;
    return (
      t?.targetKey === this.args.blockKey &&
      t?.position === position &&
      t?.outletName === this.args.outletName
    );
  }

  /**
   * Drop-target gate — rejects drops that would re-insert a block onto its
   * own zones (a no-op anyway) and consults the editor service for outlet-
   * level allowed/denied checks. The modifier filters drags whose `kind`
   * isn't `"ve-block"` or `"ve-palette-block"`, so this only fires for
   * our own payloads.
   *
   * Move drags (`ve-block`) consult `canDropAt` against the active drag
   * source; palette inserts (`ve-palette-block`) consult
   * `canInsertBlockAt` against the source's `blockName`.
   */
  @action
  canDropOnThisBlock({ source }) {
    if (source?.kind === "ve-palette-block") {
      return this.visualEditor.canInsertBlockAt({
        blockName: source.data?.blockName,
        targetOutletName: this.args.outletName,
      });
    }
    if (source?.data?.blockKey === this.args.blockKey) {
      return false;
    }
    return this.visualEditor.canDropAt({
      targetOutletName: this.args.outletName,
    });
  }

  /**
   * Adapts the core modifier's `{data, event}` drag-start payload into the
   * shape `visualEditor.startDrag` expects (a flat
   * `{blockKey, outletName}`). The data was attached at the `draggable-item`
   * call site as `(hash blockKey=… outletName=…)`.
   */
  @action
  handleDragStart({ data }) {
    this.visualEditor.startDrag(data);
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
    this.visualEditor.setActiveDropTarget({
      targetKey: this.args.blockKey,
      position,
      outletName: this.args.outletName,
    });
  }

  @action
  handleZoneDragLeave({ position }) {
    this.visualEditor.clearActiveDropTarget({
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
    this.visualEditor.removeBlock(this.args.blockKey);
  }

  /**
   * Translates a drop-zone payload into either a move (existing
   * chrome-to-chrome drag) or an insert (palette-driven drag). The
   * branch reads from `source.kind`, set by the originating modifier
   * call site — `"ve-block"` for moves, `"ve-palette-block"` for
   * palette inserts.
   */
  @action
  applyDrop({ source, position }) {
    if (source?.kind === "ve-palette-block") {
      this.visualEditor.insertBlock({
        blockName: source.data.blockName,
        defaultArgs: source.data.defaultArgs,
        targetKey: this.args.blockKey,
        position,
        targetOutletName: this.args.outletName,
      });
    } else {
      this.visualEditor.moveBlock({
        sourceKey: source.data.blockKey,
        targetKey: this.args.blockKey,
        position,
        targetOutletName: this.args.outletName,
      });
    }
    this.visualEditor.endDrag();
  }

  <template>
    {{#if this.isTransparent}}
      {{! Transparent blocks (`ve:slot`) get a positioned wrapper but
        no chrome decoration. The wrapper IS the direct child of the
        parent (e.g. a grid layout) and carries grid-column /
        grid-row from the wrapped block's args, so CSS Grid honours
        placement regardless of what's inside the slot. }}
      {{! Slot wrapper IS the cell. The wrapper renders ALWAYS so the
        live page lays out cells correctly; the chrome decoration
        (border, handle, resize, badge) is only added when the editor
        is active. SCSS scopes the visible decoration to
        `body.visual-editor-active` for the same reason. }}
      <div
        class={{dConcatClass
          "visual-editor-transparent-slot"
          (if this.isInnerSelected "--selected")
          (if this.hasGridOverlap "--overlapping")
        }}
        style={{this.transparentWrapperStyle}}
        data-ve-block-name={{@blockName}}
        data-ve-block-key={{@blockKey}}
        role={{if this.visualEditor.isActive "button"}}
        tabindex={{if this.visualEditor.isActive "0"}}
        {{didInsert this.captureChromeEl}}
        {{on "click" this.onClick}}
      >
        {{#if this.visualEditor.isActive}}
          {{#if this.hasGridOverlap}}
            <span
              class="visual-editor-block-chrome__overlap-badge"
              title={{i18n "visual_editor.canvas.overlap_warning"}}
            >
              {{dIcon "triangle-exclamation"}}
              <span>{{i18n "visual_editor.canvas.overlap_label"}}</span>
            </span>
          {{/if}}

          <span
            class="visual-editor-block-handle"
            title={{i18n "visual_editor.canvas.drag_handle_title"}}
            {{dDragAndDropSource
              kind="ve-block"
              data=(hash blockKey=@blockKey outletName=@outletName)
              dragImage=this._chromeEl
              onDragStart=this.handleDragStart
              onDragEnd=this.visualEditor.endDrag
            }}
          >
            {{dIcon "grip-lines"}}
            <span>{{i18n "visual_editor.canvas.grid_overlay.drag_tile"}}</span>
          </span>
        {{/if}}

        <@WrappedComponent />

        {{#if this.isInnerSelected}}
          <span
            class="visual-editor-block-chrome__resize-handle"
            title={{i18n "visual_editor.canvas.resize_handle_title"}}
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
      </div>
    {{else if this.visualEditor.isActive}}
      {{! Outer wrapper hosts the sibling drop zones (before/after) and the
        bordered frame in between. The dotted block-chrome border is on the
        inner element so the before/after zones render visually OUTSIDE the
        block — matching the move semantics ("place adjacent to this block
        at the parent's level"). Inside zones (containers only) sit within
        the frame, signalling "place as the container's first child". }}
      <div class="visual-editor-block-chrome-wrapper">
        {{#if this.showsSiblingDropZones}}
          <div
            class={{dConcatClass
              "visual-editor-drop-zone --before"
              (if (this.isDropZoneActive "before") "--active")
            }}
            data-ve-position="before"
            {{dDragAndDropTarget
              accepts=this.acceptedDragKinds
              position="before"
              canDrop=this.canDropOnThisBlock
              onDragEnter=this.handleZoneDragEnter
              onDragLeave=this.handleZoneDragLeave
              onDrop=this.applyDrop
            }}
          ></div>
        {{/if}}

        <div
          class={{dConcatClass
            "visual-editor-block-chrome"
            (if this.isSelected "--selected")
            (if this.isContainer "--container")
            (if this.isEmptyContainer "--empty-container")
            (if this.isInFreeGridSlot "--in-grid-slot")
            (if this.hasGridOverlap "--overlapping")
          }}
          data-ve-block-name={{@blockName}}
          data-ve-block-key={{@blockKey}}
          data-ve-empty={{this.isEmptyContainer}}
          {{didInsert this.captureChromeEl}}
          {{on "click" this.onClick}}
          role="button"
          tabindex="0"
        >
          {{#if this.isSelected}}
            <BlockToolbar @blockKey={{@blockKey}} />
          {{/if}}

          {{! Overlap warning badge — only visible when this slot's cell
            rectangle intersects a sibling slot's. Loud on purpose: the
            chrome's tinted background alone is too easy to miss, and
            silent overlap was the original complaint. }}
          {{#if this.hasGridOverlap}}
            <span
              class="visual-editor-block-chrome__overlap-badge"
              title={{i18n "visual_editor.canvas.overlap_warning"}}
            >
              {{dIcon "triangle-exclamation"}}
              <span>{{i18n "visual_editor.canvas.overlap_label"}}</span>
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
            class="visual-editor-block-handle"
            title={{i18n "visual_editor.canvas.drag_handle_title"}}
            {{dDragAndDropSource
              kind="ve-block"
              data=(hash blockKey=@blockKey outletName=@outletName)
              dragImage=this._chromeEl
              onDragStart=this.handleDragStart
              onDragEnd=this.visualEditor.endDrag
            }}
          >
            {{dIcon "grip-lines"}}
            <span>{{this.displayName}}</span>
          </span>

          <@WrappedComponent />

          {{#if this.showsGridOverlay}}
            <GridOverlay @gridKey={{@blockKey}} @outletName={{@outletName}} />
          {{/if}}

          {{! Resize handle for blocks inside grid slots lives on
            the slot wrapper itself (transparent path above), not on
            the inner chrome — that's where it aligns with the cell
            outline and corner. Nothing rendered here. }}

          {{#if this.showsInsideDropZone}}
            <div
              class={{dConcatClass
                "visual-editor-drop-zone --inside"
                (if this.isEmptyContainer "--empty")
                (if (this.isDropZoneActive "inside") "--active")
              }}
              data-ve-position="inside"
              {{dDragAndDropTarget
                accepts=this.acceptedDragKinds
                position="inside"
                canDrop=this.canDropOnThisBlock
                onDragEnter=this.handleZoneDragEnter
                onDragLeave=this.handleZoneDragLeave
                onDrop=this.applyDrop
              }}
            >
              <span class="visual-editor-drop-zone__label">
                {{#if this.isEmptyContainer}}
                  {{i18n "visual_editor.canvas.empty_container_hint"}}
                {{else}}
                  {{i18n "visual_editor.canvas.drop_inside"}}
                {{/if}}
              </span>
            </div>
          {{/if}}
        </div>

        {{#if this.showsSiblingDropZones}}
          <div
            class={{dConcatClass
              "visual-editor-drop-zone --after"
              (if (this.isDropZoneActive "after") "--active")
            }}
            data-ve-position="after"
            {{dDragAndDropTarget
              accepts=this.acceptedDragKinds
              position="after"
              canDrop=this.canDropOnThisBlock
              onDragEnter=this.handleZoneDragEnter
              onDragLeave=this.handleZoneDragLeave
              onDrop=this.applyDrop
            }}
          ></div>
        {{/if}}
      </div>
    {{else}}
      <@WrappedComponent />
    {{/if}}
  </template>
}
