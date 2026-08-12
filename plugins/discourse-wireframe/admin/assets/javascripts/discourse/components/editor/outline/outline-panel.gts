import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedMap, trackedSet } from "@ember/reactive/collections";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { TrackedAsyncData } from "ember-async-data";
import type { BlockMetadata } from "discourse/blocks/types";
import type MenuService from "discourse/float-kit/services/menu";
import type BlocksService from "discourse/services/blocks";
import DButton from "discourse/ui-kit/d-button";
import DFilterInput from "discourse/ui-kit/d-filter-input";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource, {
  type DragSource,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget, {
  type DropTargetEvent,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";
import OutlineRowActions from "discourse/plugins/discourse-wireframe/discourse/components/editor/outline/outline-row-actions";
import {
  normalizeLayoutMode,
  type OutletOutline,
  type OutlineRow,
  walkAllOutlets,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/walk-layout";
import type WireframeBlockMutationsService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-block-mutations";
import type WireframeBlockRevealService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-block-reveal";
import WireframeDragSessionService, {
  type BlockDragPayload,
  type PaletteDragPayload,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-drag-session";
import type WireframeEditModeService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-edit-mode";
import type WireframeLayoutSignalService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-signal";
import type WireframeMutationEngineService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-mutation-engine";
import WireframeSelectionService, {
  type SelectedBlockData,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-selection";

type OutlineStatusFilter = "all" | "errors" | "conditions";
type OutlineDragKind = "wf-block" | "wf-palette-block";

type DecoratedOutlineRow = OutlineRow & {
  /** Whether the row's conditions pass under the active context. */
  conditionPassing: boolean;
  /** Whether the row is hidden by its conditions. */
  conditionFailing: boolean;
  /** Whether permissive layout validation reported a failure. */
  hasValidationError: boolean;
  /** Whether the row represents an authoring error. */
  hasError: boolean;
  /** Whether the row should use hidden-content presentation. */
  isMuted: boolean;
  /** Normalized layout mode for a layout block. */
  layoutMode: string | null;
  /** One-based accessibility tree level. */
  ariaLevel: number;
  /** Icon describing the row's current status. */
  statusIcon: string | null;
  /** Tooltip describing the row's current status. */
  statusTooltip: string | null;
  /** Icon representing the row's block type. */
  typeIcon: string;
};

type OutlineGroup<Row = OutlineRow> = Omit<OutletOutline, "rows"> & {
  /** Flattened and optionally decorated rows for the outlet. */
  rows: Row[];
};

type BlockDragData = BlockDragPayload & {
  /** Whether the dragged row is a synthesized composite part. */
  isPart?: boolean;
};

type LocatedOutlineRow = {
  /** Outlet containing the row. */
  outletName: string;
  /** Decorated row located by stable key. */
  row: DecoratedOutlineRow;
};

type CollapsedAncestor = {
  /** Depth of the collapsed ancestor. */
  depth: number;
  /** Composite key of the collapsed ancestor. */
  key: string;
};

interface OutlinePanelSignature {
  /** The panel accepts no named arguments. */
  Args: Record<string, never>;
}

/**
 * Builds the inline indentation for one tree depth.
 *
 * The base 1rem offset indents every row at least one level under the outlet
 * label. The value is computed from a number rather than user-provided CSS.
 *
 * @param depth - Zero-based nesting depth.
 * @returns Trusted inline padding style.
 */
function rowPadding(depth: number): ReturnType<typeof trustHTML> {
  return trustHTML(`padding-left: ${1 + depth * 0.75}rem;`);
}

// A container with more than this many children starts collapsed in the
// outline (showing a "× N" count badge) so a large layout — a 12-card grid, a
// long carousel — stays scannable instead of flooding the tree. The user can
// still expand it; their explicit choice overrides this default.
const CHILD_COUNT_THRESHOLD = 6;

// FloatKit identifier for the per-row kebab menu, so only one is ever open.
const ROW_ACTIONS_MENU = "wireframe-outline-row-actions";

/**
 * Read-only outline of registered block outlet layouts. Renders one section
 * per outlet, each containing a flattened tree of its blocks. Clicking a row
 * mirrors the canvas: it sets the selected block in the editor service so the
 * inspector populates and the matching block on the canvas highlights.
 */
export default class OutlinePanel extends Component<OutlinePanelSignature> {
  /** Resolves registered block metadata and conditions. */
  @service declare blocks: BlocksService;
  /** Opens the per-row action menu. */
  @service declare menu: MenuService;
  /** Applies structural mutations initiated from the outline. */
  @service declare wireframeBlockMutations: WireframeBlockMutationsService;
  /** Scrolls and flashes selected blocks on the canvas. */
  @service declare wireframeBlockReveal: WireframeBlockRevealService;
  /** Owns active outline drag state. */
  @service declare wireframeDragSession: WireframeDragSessionService;
  /** Exposes layout snapshots used by the outline projection. */
  @service declare wireframeMutationEngine: WireframeMutationEngineService;
  /** Invalidates the outline after layout changes. */
  @service declare wireframeLayoutSignal: WireframeLayoutSignalService;
  /** Owns the current block selection. */
  @service declare wireframeSelection: WireframeSelectionService;
  /** Exposes whether the editor is active. */
  @service declare wireframeEditMode: WireframeEditModeService;

  /**
   * Free-text query that filters tree rows by block name / id (case-
   * insensitive substring). Empty string disables the filter.
   */
  @tracked query = "";

  /**
   * Status filter chip. `"all"` shows every row, `"errors"` shows rows
   * with any failure status (unknown block, condition failing), and
   * `"conditions"` shows rows that have conditions at all. Single-select.
   */
  @tracked statusFilter: OutlineStatusFilter = "all";
  /** Drag kinds accepted by outline drop targets. */
  acceptedDragKinds: OutlineDragKind[] = ["wf-block", "wf-palette-block"];
  /**
   * Checks whether a status-filter chip is selected.
   *
   * @param filter - Filter represented by the chip.
   */
  isStatusFilter: (filter: OutlineStatusFilter) => boolean = (filter) =>
    this.statusFilter === filter;
  /**
   * Whether a container row is collapsed. A row the user has explicitly toggled
   * uses that choice; otherwise it falls back to the default — collapsed when
   * the child count exceeds the threshold, expanded below it.
   *
   * @param row - The outline row carrying the block key and child count.
   */
  isRowCollapsed: (row: OutlineRow) => boolean = (row) =>
    this.#collapseOverrides.get(row.blockKey) ??
    row.childCount > CHILD_COUNT_THRESHOLD;
  /**
   * Checks whether an outlet group is collapsed.
   *
   * @param outletName - Registered outlet name.
   */
  isOutletCollapsed: (outletName: string) => boolean = (outletName) =>
    this.#collapsedOutlets.has(outletName);

  /**
   * Whether `rootKey` is the current selection — drives the outlet header's
   * selected styling.
   *
   * @param rootKey - Composite key of the outlet root.
   */
  isOutletSelected: (rootKey: string | null) => boolean = (rootKey) => {
    return rootKey != null && this.wireframeSelection.isBlockSelected(rootKey);
  };
  /**
   * Explicit per-row collapse choices keyed by `blockKey` (`true` = collapsed,
   * `false` = expanded). Only rows the user has toggled appear here; everything
   * else uses the threshold default in `isRowCollapsed`. Rows whose ancestor
   * chain resolves to collapsed are filtered out of `decoratedGroups`.
   * Session-only — resets on editor exit, mirroring how transient UI state lives.
   */
  #collapseOverrides = trackedMap<string, boolean>();

  /**
   * Outlet names the user has collapsed in the tree view. When an
   * outlet is collapsed the group header still renders (so the user
   * can expand it again) but its row list is suppressed.
   */
  #collapsedOutlets = trackedSet<string>();

  /**
   * Lazy `blockName -> metadata` index built on first row selection.
   * Each row in the outline maps to a single block class; caching the
   * whole registry up-front would walk every block on first render
   * even for outlets the author never opens, so we build it on demand.
   */
  #metaIndex: Map<string, BlockMetadata | null> | null = null;

  /**
   * Wraps the async outlet walk in `TrackedAsyncData` so the template
   * can read `.value` without juggling a `@tracked outlets` field and
   * a `didUpdate`-driven `refresh()`. Recomputes when:
   *
   *   - `wireframeEditMode.active` flips (editor opens / closes)
   *   - `wireframeLayoutSignal.version` bumps (structural mutation lands; the layer
   *     is republished and validation re-runs against the fresh entries)
   *   - any entry's soft-failure stamp changes — `walkAllOutlets`'s sync
   *     prefix touches `__failureType` / `__failureReason` on every
   *     entry before its first `await`, so the per-key tag deps on the
   *     trackedObject-wrapped entries attach to this getter's tracking
   *     frame. `clearValidatorStamps` then propagates straight through.
   *
   * `alwaysInclude` keeps outlets the editor has touched in the walk
   * even when their boundary div briefly leaves the DOM between
   * publish and re-render (DAsyncContent's `:loading` block paints
   * nothing in the gap).
   */
  @cached
  get outletsData(): TrackedAsyncData<OutlineGroup[]> {
    void this.wireframeEditMode.active;
    void this.wireframeLayoutSignal.version;
    return new TrackedAsyncData<OutlineGroup[]>(
      // TODO(devxp-typescript-pending): remove this boundary cast once
      // walk-layout is authored in TypeScript and exports its row contract.
      walkAllOutlets({
        blocksService: this.blocks,
        alwaysInclude: new Set(
          this.wireframeMutationEngine.draftedOutletNames()
        ),
      }) as Promise<OutlineGroup[]>
    );
  }

  /**
   * Resolved walk result (or an empty list while the first walk is
   * still pending). Downstream getters key off this rather than the
   * full `TrackedAsyncData` shape — they don't need the loading state.
   *
   * `TrackedAsyncData#value` throws unless `.isResolved` — guard
   * explicitly so the first render (before the walk's promise has
   * settled) returns `[]` instead of crashing.
   */
  get outlets(): OutlineGroup[] {
    return this.outletsData.isResolved ? this.outletsData.value : [];
  }

  /**
   * Decorated rows grouped by outlet. Joins the raw walker output with
   * derived per-row status (condition pass/fail, unknown-block) so the
   * template can render the right icon without computing anything inline.
   *
   * `@cached` keeps this stable across renders — it only recomputes when
   * one of its tracked reads (`this.outlets`, query / filter, sim state
   * via `evaluate`) changes.
   *
   */
  @cached
  get decoratedGroups(): Array<OutlineGroup<DecoratedOutlineRow>> {
    const q = this.query.trim().toLowerCase();
    const status = this.statusFilter;
    return this.outlets.map((group) => {
      const decorated = group.rows.map((row) => this.#decorateRow(row));
      const visible = this.#dropCollapsedDescendants(decorated);
      const rows = visible.filter((row) =>
        this.#matchesFilters(row, q, status)
      );
      return {
        outletName: group.outletName,
        rows,
        rootKey: group.rootKey,
        mode: group.mode,
      };
    });
  }

  /**
   * Toggles the collapse state for a container row. No-op for leaves.
   *
   * DButton stops propagation of its own click, so the surrounding
   * row's selection handler does not also fire.
   *
   * @param row - Container row whose collapse state should toggle.
   */
  @action
  toggleCollapse(row: OutlineRow): void {
    if (!row.hasChildren) {
      return;
    }
    // Record the flipped state as an explicit override so it sticks against the
    // threshold default (a big container the user expanded stays expanded).
    this.#collapseOverrides.set(row.blockKey, !this.isRowCollapsed(row));
  }

  /**
   * Toggles the collapse state for an outlet group header. Hides the
   * outlet's rows in the tree view while keeping its label visible
   * so the user can re-expand.
   *
   * @param outletName - Outlet group to toggle.
   */
  @action
  toggleOutlet(outletName: string): void {
    if (this.#collapsedOutlets.has(outletName)) {
      this.#collapsedOutlets.delete(outletName);
    } else {
      this.#collapsedOutlets.add(outletName);
    }
  }

  /**
   * Selects the clicked row, honoring modifier keys to build a multi-selection:
   * cmd/ctrl-click toggles the row in/out of the selection, shift-click selects
   * the contiguous range from the current primary to the clicked row (within
   * the same outlet's visible rows), and a plain click selects just this row.
   *
   * @param outletName - The owning outlet's name; rows do not carry it.
   * @param row - A row produced by `walkAllOutlets`.
   * @param event - The click or activation event carrying modifier-key state.
   */
  @action
  selectRow(
    outletName: string,
    row: OutlineRow,
    event?: MouseEvent | KeyboardEvent
  ): void {
    const data = this.#rowData(outletName, row);

    if (event?.metaKey || event?.ctrlKey) {
      this.wireframeSelection.toggleBlockSelection(data);
    } else if (event?.shiftKey) {
      const keys = this.#rangeKeys(outletName, row);
      if (keys) {
        this.wireframeSelection.setSelectionRange(keys, data);
      } else {
        this.wireframeSelection.selectBlock(data);
      }
    } else {
      this.wireframeSelection.selectBlock(data);
    }

    // Flash the block on the canvas so the eye lands on it after it scrolls
    // into view — the outline row is far from the rendered block.
    this.wireframeBlockReveal.flash(row.blockKey);
  }

  /**
   * Builds the selection payload for a row (the shape `selectBlock` and the
   * multi-select gestures expect).
   *
   * @param outletName - Outlet containing the row.
   * @param row - Outline row to project.
   * @returns Selection payload for the row.
   */
  #rowData(outletName: string, row: OutlineRow): SelectedBlockData {
    return {
      key: row.blockKey,
      name: row.blockName,
      id: row.blockId,
      args: row.args,
      conditions: row.conditions,
      outletName,
      metadata: this.lookupMetadataFor(row.blockName),
    };
  }

  /**
   * The block keys spanning the current primary selection and `toRow`, within
   * the clicked outlet's visible rows — the shift-click range. Returns `null`
   * when there's no anchor or either endpoint isn't a visible row (e.g. the
   * anchor is in another outlet or hidden under a collapsed container), so the
   * caller falls back to a plain single select.
   *
   * @param outletName - Outlet whose visible rows define the range.
   * @param toRow - Row terminating the range.
   * @returns Contiguous block keys, or `null` without a visible anchor.
   */
  #rangeKeys(outletName: string, toRow: OutlineRow): string[] | null {
    const anchorKey = this.wireframeSelection.selectedBlockKey;
    if (!anchorKey) {
      return null;
    }
    const group = this.decoratedGroups.find((g) => g.outletName === outletName);
    const rows = group?.rows ?? [];
    const anchorIndex = rows.findIndex((r) => r.blockKey === anchorKey);
    const toIndex = rows.findIndex((r) => r.blockKey === toRow.blockKey);
    if (anchorIndex === -1 || toIndex === -1) {
      return null;
    }
    const [lo, hi] =
      anchorIndex <= toIndex ? [anchorIndex, toIndex] : [toIndex, anchorIndex];
    return rows.slice(lo, hi + 1).map((r) => r.blockKey);
  }

  /**
   * Selects an outlet by selecting its implicit root layout — the outline
   * header acts as the outlet's selection target, surfacing the layout form.
   *
   * @param outletName - Outlet whose root should be selected.
   */
  @action
  selectOutletRoot(outletName: string): void {
    this.wireframeSelection.selectOutlet(outletName);
  }

  /**
   * Keyboard activation (Enter / Space) for a tree item, dispatched by the
   * `dRovingFocus` modifier. The modifier hands back the focused DOM element,
   * so we branch on which kind of item it is and read the identity off the
   * element's data attributes:
   *   - an outlet header selects that outlet's implicit root layout,
   *   - a block row runs the same selection path as a click.
   *
   * @param element - The focused tree item.
   * @param event - Forwarded so `selectRow` can honor modifier keys.
   */
  @action
  activateTreeItem(element: HTMLElement, event: KeyboardEvent): void {
    if (element.classList.contains("outline-outlet__header")) {
      const { outletName } = element.dataset;
      if (outletName) {
        this.selectOutletRoot(outletName);
      }
      return;
    }
    const found = this.#findRow(element.dataset.blockKey);
    if (found) {
      this.selectRow(found.outletName, found.row, event);
    }
  }

  /**
   * Tree expand/collapse via Left/Right arrows. The `dRovingFocus` modifier
   * runs in vertical orientation, so it leaves Left/Right un-prevented for this
   * sibling handler: Right expands a collapsed container, Left collapses an
   * expanded one. Leaves and already-in-state containers are a no-op, so the
   * event stays un-prevented and can bubble.
   *
   * @param event - Tree keyboard event.
   */
  @action
  onTreeKeydown(event: KeyboardEvent): void {
    if (event.key !== "ArrowRight" && event.key !== "ArrowLeft") {
      return;
    }
    const element = document.activeElement;
    if (!(element instanceof HTMLElement)) {
      return;
    }
    const expand = event.key === "ArrowRight";

    if (element.classList.contains("outline-outlet__header")) {
      const { outletName } = element.dataset;
      if (outletName && this.isOutletCollapsed(outletName) === expand) {
        event.preventDefault();
        this.toggleOutlet(outletName);
      }
      return;
    }

    const found = this.#findRow(element.dataset.blockKey);
    if (found?.row.hasChildren && this.isRowCollapsed(found.row) === expand) {
      event.preventDefault();
      this.toggleCollapse(found.row);
    }
  }

  /**
   * Opens the row's kebab overflow menu (Duplicate / Delete) anchored to the
   * clicked button. Uses FloatKit's programmatic `menu.show` so exactly one
   * menu instance exists regardless of row count, mirroring core's
   * DButton-triggered menu pattern (`topic-bookmarks-menu`): DButton defers its
   * action through the runloop and clears `currentTarget`, so the trigger
   * element is recovered via `event.target.closest`.
   *
   * @param row - The decorated row the actions apply to.
   * @param event - Forwarded by DButton through `@forwardEvent`.
   */
  @action
  openRowActions(row: DecoratedOutlineRow, event: MouseEvent): void {
    if (!(event.target instanceof Element)) {
      return;
    }
    const trigger = event.target.closest<HTMLElement>(
      ".outline-block__actions"
    );
    if (!trigger) {
      return;
    }
    // Select the row this menu acts on, exactly as a row click would, so the
    // acted-on item is clearly highlighted and the inspector reflects it while
    // the menu is open.
    const found = this.#findRow(row.blockKey);
    if (found) {
      this.selectRow(found.outletName, found.row, event);
    }
    // `autofocus` moves focus into the menu (its first item) so it's keyboard-
    // operable; Tab cycles the items and Escape closes, returning focus to the
    // trigger. The trigger is the kebab inside the row, so `dRovingFocus`
    // resolves the tree cursor back to that row and arrow-nav resumes there.
    this.menu.show(trigger, {
      identifier: ROW_ACTIONS_MENU,
      component: OutlineRowActions,
      placement: "bottom-end",
      autofocus: true,
      data: {
        onDuplicate: () =>
          this.wireframeBlockMutations.duplicateBlock(row.blockKey),
        onDelete: () => this.wireframeBlockMutations.removeBlock(row.blockKey),
      },
    });
  }

  /**
   * Resolves a decorated row (and its owning outlet) from a block key by
   * scanning the current groups. Called only on a keyboard activation, so the
   * linear scan is cheap relative to a per-render index.
   *
   * @param blockKey - Composite row key to locate.
   * @returns The row and owning outlet, or `null` when absent.
   */
  #findRow(blockKey: string | undefined): LocatedOutlineRow | null {
    if (!blockKey) {
      return null;
    }
    for (const group of this.decoratedGroups) {
      const row = group.rows.find((r) => r.blockKey === blockKey);
      if (row) {
        return { outletName: group.outletName, row };
      }
    }
    return null;
  }

  /**
   * Resolves cached metadata for a registered block name.
   *
   * @param blockName - Registered block name.
   * @returns The block metadata, or `null` when unregistered.
   */
  lookupMetadataFor(blockName: string): BlockMetadata | null {
    if (!this.#metaIndex) {
      this.#metaIndex = new Map(
        this.blocks
          .listBlocksWithMetadata()
          .map(({ name, metadata }) => [name, metadata])
      );
    }
    return this.#metaIndex.get(blockName) ?? null;
  }

  /**
   * Adapts the source modifier's `{source}` payload into the flat
   * `{blockKey, outletName}` argument the editor service expects.
   * The data was attached at the `dDragAndDropSource` call site as
   * `(hash blockKey=… outletName=…)` and exposed back under
   * `source.data`.
   *
   * @param event - Drag-start event supplied by the source modifier.
   */
  @action
  handleRowDragStart({ source }: { source: DragSource }): void {
    // Synthesized composite parts aren't reorderable — never start a drag for
    // one. (The underlying move would no-op anyway, but this avoids the
    // misleading drag affordance.)
    const data = source.data as unknown as BlockDragData;
    if (data?.isPart) {
      return;
    }
    this.wireframeDragSession.startDrag(data);
  }

  /**
   * Drop-target for an outline row. Maps every drop into a `before`
   * action — the outline is a flat ordered list, so "drop on row X"
   * reads as "place above row X". Branches on `source.type` to support
   * both moves (existing block dragged within the tree) and inserts
   * (palette block dropped onto an outline row).
   *
   * @param outletName - The outlet containing the target row.
   * @param row - A row produced by `walkAllOutlets`.
   * @param target - The normalized drag source payload from the target modifier.
   */
  @action
  applyRowDrop(
    outletName: string,
    row: OutlineRow,
    target: DropTargetEvent
  ): void {
    // A synthesized composite part isn't a real layout position — dropping
    // onto/around it can't move or insert anything, so ignore the drop.
    if (row.isPart) {
      this.wireframeDragSession.endDrag();
      return;
    }
    const { source } = target;
    if (source?.type === "wf-palette-block") {
      const data = source.data as unknown as PaletteDragPayload;
      this.wireframeBlockMutations.insertBlock({
        blockName: data.blockName,
        defaultArgs: data.defaultArgs,
        targetKey: row.blockKey,
        position: "before",
        targetOutletName: outletName,
      });
    } else {
      const data = source.data as unknown as BlockDragData;
      this.wireframeBlockMutations.moveBlock({
        sourceKey: data.blockKey,
        targetKey: row.blockKey,
        position: "before",
        targetOutletName: outletName,
      });
    }
    this.wireframeDragSession.endDrag();
  }

  /**
   * Checks whether a row is the active drag source.
   *
   * @param blockKey - Composite row key.
   * @returns Whether the row owns the active drag.
   */
  @action
  isRowDragSource(blockKey: string): boolean {
    return this.wireframeDragSession.sourceKey === blockKey;
  }

  /**
   * Selects an outline status filter.
   *
   * @param filter - Filter to activate.
   */
  @action
  setStatusFilter(filter: OutlineStatusFilter): void {
    this.statusFilter = filter;
  }

  /**
   * Updates the free-text outline query.
   *
   * @param event - Search input event.
   */
  @action
  onQueryInput(
    event: Event & {
      /** Search input that emitted the event. */
      currentTarget: Element;
    }
  ): void {
    if (event.currentTarget instanceof HTMLInputElement) {
      this.query = event.currentTarget.value;
    }
  }

  /** Clears the free-text outline query. */
  @action
  clearQuery(): void {
    this.query = "";
  }

  /**
   * Walks the DFS-ordered row list and drops every row whose ancestor
   * chain includes a collapsed `blockKey`. Uses the depth field on
   * each row to track the active ancestor stack — when we re-enter a
   * shallower depth, the deeper ancestors are popped automatically.
   *
   * @param rows - DFS-ordered, depth-aware rows.
   */
  #dropCollapsedDescendants(
    rows: DecoratedOutlineRow[]
  ): DecoratedOutlineRow[] {
    const collapsedAncestors: CollapsedAncestor[] = [];
    const result: DecoratedOutlineRow[] = [];
    for (const row of rows) {
      while (
        collapsedAncestors.length > 0 &&
        collapsedAncestors[collapsedAncestors.length - 1].depth >= row.depth
      ) {
        collapsedAncestors.pop();
      }
      if (collapsedAncestors.length > 0) {
        // Suppressed by a collapsed ancestor — skip but still consider
        // whether this row itself is also collapsed (so its own
        // descendants stay suppressed even if a deeper grandparent
        // expands later).
        if (row.hasChildren && this.isRowCollapsed(row)) {
          collapsedAncestors.push({ depth: row.depth, key: row.blockKey });
        }
        continue;
      }
      result.push(row);
      if (row.hasChildren && this.isRowCollapsed(row)) {
        collapsedAncestors.push({ depth: row.depth, key: row.blockKey });
      }
    }
    return result;
  }

  /**
   * Returns true when the row passes both the text search and status
   * chip. Hidden behind the filter pipeline so the template stays free
   * of conditional logic.
   *
   * @param row - The decorated row being tested.
   * @param normalizedQuery - The already lowercased and trimmed query.
   * @param status - The active status filter.
   */
  #matchesFilters(
    row: DecoratedOutlineRow,
    normalizedQuery: string,
    status: OutlineStatusFilter
  ): boolean {
    if (normalizedQuery) {
      const name = row.blockName?.toLowerCase() ?? "";
      const id = row.blockId?.toLowerCase() ?? "";
      if (!name.includes(normalizedQuery) && !id.includes(normalizedQuery)) {
        return false;
      }
    }
    if (status === "errors") {
      return row.hasError;
    }
    if (status === "conditions") {
      return row.hasConditions;
    }
    return true;
  }

  /**
   * Adds per-row status flags used by the template. Resolves the row's
   * condition spec against the blocks service so a passing-but-gated
   * block (lock icon) is distinguishable from a failing one (eye-slash).
   *
   * Wrapped in try/catch because condition specs can throw on malformed
   * input (the resolver leaves a `__failureType` behind for those, but
   * the walker exposes the raw spec — same data, different surface);
   * treating a throw as "condition failed" keeps the outline readable
   * either way.
   *
   * @param row - Raw outline row to decorate.
   * @returns The row plus status and accessibility presentation.
   */
  #decorateRow(row: OutlineRow): DecoratedOutlineRow {
    let conditionPassing = true;
    if (row.hasConditions) {
      try {
        conditionPassing = !!this.blocks.evaluate(row.conditions);
      } catch {
        conditionPassing = false;
      }
    }
    const conditionFailing = row.hasConditions && !conditionPassing;
    // `validationFailure` carries soft-failures from the layout validator
    // (e.g. an empty container, args mismatch). Treat them as errors
    // alongside unknown blocks — both are author-facing problems.
    const hasValidationError = !!row.validationFailure;
    // `hasError` mirrors the canvas ghost's `--error` modifier — danger-
    // tone is reserved for genuine authoring mistakes (UNKNOWN_BLOCK,
    // structural-invalid). Condition-failed is intentional gating; it
    // shows the eye-slash icon but stays in neutral row colors so the
    // outline doesn't shout at the author about their own conditions.
    const hasError = row.isUnknown || hasValidationError;
    // `isMuted` matches the canvas ghost's faded silhouette: a block
    // that's hidden by its own conditions isn't an authoring mistake,
    // it's just not rendering right now. Dim the row so the outline
    // signals "won't show on the live page" without using error red.
    const isMuted = !hasError && conditionFailing;
    // Nested `layout` blocks carry the same `mode` arg as the outlet's
    // implicit root layout (stack / row / grid). Surface it as a chip on
    // the row so the structure reads at a glance — mirrors the mode chip
    // the outlet header shows for its root layout. Non-layout blocks get
    // `null` so the badge only renders where a mode is meaningful.
    const mode = row.args?.mode;
    const layoutMode =
      row.blockName === "layout"
        ? normalizeLayoutMode(typeof mode === "string" ? mode : undefined)
        : null;
    // `aria-level` for the flattened tree: the outlet header is level 1, so a
    // top-level row (depth 0) is level 2, and so on. Computed here in the single
    // decoration pass rather than as a per-row template getter.
    const ariaLevel = row.depth + 2;
    return {
      ...row,
      conditionPassing,
      conditionFailing,
      hasValidationError,
      hasError,
      isMuted,
      layoutMode,
      ariaLevel,
      statusIcon: this.#statusIconFor(row, conditionFailing),
      statusTooltip: this.#statusTooltipFor(row, conditionFailing),
      typeIcon: this.#typeIconFor(row),
    };
  }

  /**
   * Picks the icon that identifies the row's block type, shown before the
   * block name so the tree is scannable at a glance.
   *   - A synthesized composite part keeps the dashed-circle "not directly
   *     editable" cue rather than borrowing its block's icon.
   *   - Otherwise the block's own declared icon; `cube` mirrors the core
   *     default for blocks that declare none (and for unknown blocks whose
   *     metadata can't be resolved).
   *
   * @param row - Outline row whose type icon should be selected.
   * @returns The block-type icon name.
   */
  #typeIconFor(row: OutlineRow): string {
    if (row.isPart) {
      return "circle-dashed";
    }
    return this.lookupMetadataFor(row.blockName)?.icon ?? "cube";
  }

  /**
   * Picks the right icon name for the row's status badge.
   *   - Unknown block → triangle-exclamation.
   *   - Conditions present and failing → eye-slash.
   *   - Conditions present and passing → lock.
   *   - Otherwise → null (no badge).
   *
   * @param row - Outline row whose status icon should be selected.
   * @param conditionFailing - Whether the row's conditions currently fail.
   * @returns The status icon name, or `null` without a status.
   */
  #statusIconFor(row: OutlineRow, conditionFailing: boolean): string | null {
    if (row.isUnknown) {
      return "triangle-exclamation";
    }
    if (row.validationFailure) {
      // Structural-invalid (e.g. an empty container, malformed args)
      // shares the unknown-block treatment — both are authoring
      // problems that need the author's attention.
      return "triangle-exclamation";
    }
    if (conditionFailing) {
      return "eye-slash";
    }
    if (row.hasConditions) {
      return "filter";
    }
    return null;
  }

  /**
   * Resolves localized status copy for an outline row.
   *
   * @param row - Outline row being decorated.
   * @param conditionFailing - Whether the row's conditions currently fail.
   * @returns The localized tooltip, or `null` without a status.
   */
  #statusTooltipFor(row: OutlineRow, conditionFailing: boolean): string | null {
    if (row.isUnknown) {
      return i18n("wireframe.outline.status.unknown_block");
    }
    if (row.validationFailure) {
      // The validator gives us a useful message string; surface it as
      // the tooltip so the author sees the specific problem without
      // having to open the inspector / read the console.
      return (
        row.validationReason ??
        i18n("wireframe.outline.status.validation_failed")
      );
    }
    if (conditionFailing) {
      return i18n("wireframe.outline.status.condition_failed");
    }
    if (row.hasConditions) {
      return i18n("wireframe.outline.status.conditions_passing");
    }
    return null;
  }

  <template>
    <div class="wireframe-outline">
      <div class="wireframe-outline__filter-bar">
        {{! Core's shared filter input: leading icon, clear button, and the
          proper container-level focus ring (a bare input would render the
          global input focus shadow as a stray inner ring). }}
        <DFilterInput
          @value={{this.query}}
          @filterAction={{this.onQueryInput}}
          @onClearInput={{this.clearQuery}}
          @icons={{hash left="magnifying-glass"}}
          placeholder={{i18n "wireframe.outline.filter.placeholder"}}
          aria-label={{i18n "wireframe.outline.filter.placeholder"}}
          spellcheck="false"
          autocomplete="off"
        />
        <div class="wireframe-outline__chips" role="tablist">
          <DButton
            class={{dConcatClass
              "wireframe-outline__chip"
              (if (this.isStatusFilter "all") "--active")
            }}
            @label="wireframe.outline.filter.chip_all"
            @action={{fn this.setStatusFilter "all"}}
          />
          <DButton
            class={{dConcatClass
              "wireframe-outline__chip"
              (if (this.isStatusFilter "errors") "--active")
            }}
            @icon="triangle-exclamation"
            @label="wireframe.outline.filter.chip_errors"
            @action={{fn this.setStatusFilter "errors"}}
          />
          <DButton
            class={{dConcatClass
              "wireframe-outline__chip"
              (if (this.isStatusFilter "conditions") "--active")
            }}
            @icon="filter"
            @label="wireframe.outline.filter.chip_conditions"
            @action={{fn this.setStatusFilter "conditions"}}
          />
        </div>
      </div>

      {{#if this.decoratedGroups.length}}
        {{! The tree is one flat roving-focus list: its DOM order (each outlet
          header followed by its visible rows) already matches the visible tree
          order, since collapsed outlets/containers render no descendants. The
          modifier owns the single tab stop and Up/Down/Home/End/Enter; Left and
          Right bubble to onTreeKeydown for expand/collapse. itemsKey re-seeds
          the tab stop whenever the row set changes (filter, collapse, delete). }}
        <div
          class="wireframe-outline__tree"
          role="tree"
          aria-label={{i18n "wireframe.outline.tree_label"}}
          {{dRovingFocus
            orientation="vertical"
            itemSelector=".outline-outlet__header, .outline-block"
            onActivate=this.activateTreeItem
            itemsKey=this.decoratedGroups
          }}
          {{on "keydown" this.onTreeKeydown}}
        >
          {{#each this.decoratedGroups key="outletName" as |group|}}
            {{! Each outlet is a group of tree nodes (its header treeitem plus
              its block-row treeitems), giving the treeitems the tree/group
              container the role requires. }}
            <div class="outline-outlet" role="group">
              {{! The header chevron toggles collapse; the label selects the
              outlet (its implicit root layout) so the inspector shows the
              layout form. Two distinct interactions, so two controls. }}
              <div
                class={{dConcatClass
                  "outline-outlet__header"
                  (if (this.isOutletSelected group.rootKey) "--selected")
                }}
                role="treeitem"
                aria-level="1"
                aria-expanded={{if
                  (this.isOutletCollapsed group.outletName)
                  "false"
                  "true"
                }}
                aria-selected={{if
                  (this.isOutletSelected group.rootKey)
                  "true"
                  "false"
                }}
                data-outlet-name={{group.outletName}}
              >
                <DButton
                  class="outline-outlet__toggle"
                  @ariaExpanded={{if
                    (this.isOutletCollapsed group.outletName)
                    false
                    true
                  }}
                  @icon={{if
                    (this.isOutletCollapsed group.outletName)
                    "chevron-right"
                    "chevron-down"
                  }}
                  @ariaLabel={{if
                    (this.isOutletCollapsed group.outletName)
                    "wireframe.outline.expand_row"
                    "wireframe.outline.collapse_row"
                  }}
                  @action={{fn this.toggleOutlet group.outletName}}
                />
                <DButton
                  class="outline-outlet__label"
                  @action={{fn this.selectOutletRoot group.outletName}}
                >
                  {{dIcon "cubes"}}
                  <span class="outline-outlet__name">{{group.outletName}}</span>
                  {{#if group.mode}}
                    <span class="outline-chip outline-outlet__mode">
                      {{i18n
                        (concat "wireframe.inspector.layout.mode_" group.mode)
                      }}
                    </span>
                  {{/if}}
                </DButton>
              </div>
              {{#unless (this.isOutletCollapsed group.outletName)}}
                {{#each group.rows key="blockKey" as |row|}}
                  <div
                    class={{dConcatClass
                      "outline-block"
                      (if
                        (this.wireframeSelection.isBlockSelected row.blockKey)
                        "--selected"
                      )
                      (if (this.isRowDragSource row.blockKey) "--dragging")
                      (if row.hasError "--error")
                      (if row.isMuted "--muted")
                      (if row.isPart "--part")
                    }}
                    role="treeitem"
                    aria-level={{row.ariaLevel}}
                    aria-selected={{if
                      (this.wireframeSelection.isBlockSelected row.blockKey)
                      "true"
                      "false"
                    }}
                    aria-expanded={{if
                      row.hasChildren
                      (if (this.isRowCollapsed row) "false" "true")
                    }}
                    data-block-key={{row.blockKey}}
                    data-outlet-name={{group.outletName}}
                    style={{rowPadding row.depth}}
                    {{on "click" (fn this.selectRow group.outletName row)}}
                    {{dDragAndDropSource
                      type="wf-block"
                      data=(hash
                        blockKey=row.blockKey
                        outletName=group.outletName
                        isPart=row.isPart
                      )
                      onDragStart=this.handleRowDragStart
                      onDragEnd=this.wireframeDragSession.endDrag
                    }}
                    {{dDragAndDropTarget
                      accepts=this.acceptedDragKinds
                      position="before"
                      onDrop=(fn this.applyRowDrop group.outletName row)
                    }}
                  >
                    {{! Drag grip — a hover-revealed affordance signalling the
                    row is draggable. The whole row is the drag source (the
                    modifiers above), so the grip is decorative; parts aren't
                    reorderable, so they get none. }}
                    {{#unless row.isPart}}
                      <span class="outline-block__grip" aria-hidden="true">
                        {{dIcon "grip-vertical"}}
                      </span>
                    {{/unless}}
                    {{! The chevron sits inside a treeitem row that also handles
                    selection. The toggle button stops its own click from
                    propagating, so the row selection does not also fire; the two
                    interactions stay logically distinct even though they nest. }}
                    {{#if row.hasChildren}}

                      <DButton
                        class="outline-block__toggle"
                        @icon={{if
                          (this.isRowCollapsed row)
                          "chevron-right"
                          "chevron-down"
                        }}
                        @ariaLabel={{if
                          (this.isRowCollapsed row)
                          "wireframe.outline.expand_row"
                          "wireframe.outline.collapse_row"
                        }}
                        @action={{fn this.toggleCollapse row}}
                      />
                    {{else}}
                      {{! An empty spacer sized to match the chevron so leaf rows
                      line up under their container's toggle. The block-type icon
                      that identifies the row now lives beside the name below. }}
                      <span class="outline-block__leaf"></span>
                    {{/if}}
                    {{! The block-type icon, shown on every row (container and
                    leaf) so the tree reads at a glance. Decorative; the block
                    name below is the row's accessible label. }}
                    <span class="outline-block__type" aria-hidden="true">
                      {{dIcon row.typeIcon}}
                    </span>
                    {{! The block name is the row's primary text; a child of an
                      ordinal-naming container (a carousel slide, a tabs panel)
                      gets its position as a separate chip below, and its own
                      label as the row's hover tooltip. }}
                    <span class="outline-block__name" title={{row.childLabel}}>
                      {{row.blockName}}
                    </span>
                    {{#if (this.isRowCollapsed row)}}
                      {{! Count badge surfacing how many child rows are hidden
                      while the container is collapsed — the compaction cue for
                      large containers. }}
                      <span class="outline-chip outline-block__child-count">
                        {{i18n
                          "wireframe.outline.child_count"
                          count=row.childCount
                        }}
                      </span>
                    {{/if}}
                    {{#if row.slideOrdinal}}
                      {{! A noun-framed container's child (a carousel slide, a tabs
                        panel) shows its 1-based position as a chip beside the
                        block name, ahead of the layout-mode chip. }}
                      <span class="outline-chip outline-block__ordinal">
                        {{i18n row.slideNumberKey number=row.slideOrdinal}}
                      </span>
                    {{/if}}
                    {{#if row.layoutMode}}
                      <span class="outline-chip outline-block__mode">
                        {{i18n
                          (concat
                            "wireframe.inspector.layout.mode_" row.layoutMode
                          )
                        }}
                      </span>
                    {{/if}}
                    {{#if row.blockId}}
                      <span class="outline-block__id">#{{row.blockId}}</span>
                    {{/if}}
                    {{#if row.statusIcon}}
                      <span
                        class="outline-block__status"
                        title={{row.statusTooltip}}
                        aria-label={{row.statusTooltip}}
                      >
                        {{dIcon row.statusIcon}}
                      </span>
                    {{/if}}
                    {{! Kebab overflow menu (Duplicate / Delete), revealed on
                    hover, focus, or selection. Opens a single on-demand FloatKit
                    menu; parts have no structural actions. Forwarding the event
                    to the action lets the trigger element be recovered for
                    anchoring. }}
                    {{#unless row.isPart}}
                      <DButton
                        class="outline-block__actions btn-flat"
                        @icon="ellipsis-vertical"
                        @ariaLabel="wireframe.outline.actions_label"
                        @actionParam={{row}}
                        @action={{this.openRowActions}}
                        @forwardEvent={{true}}
                      />
                    {{/unless}}
                  </div>
                {{/each}}
              {{/unless}}
            </div>
          {{/each}}
        </div>
      {{else}}
        <div class="panel-empty">{{i18n "wireframe.outline.empty"}}</div>
      {{/if}}
    </div>
  </template>
}
