import Service, { service } from "@ember/service";
import { LAYOUT_MERGED_CELL_BLOCK, parsePlacement } from "discourse/blocks";
import type { LayoutEntry } from "discourse/blocks/types";
import { positionEntering } from "discourse/plugins/discourse-wireframe/discourse/lib/grid/grid-placement";
// `grid-math` holds the editor-only grid geometry. Absolute addon path
// because this admin service crosses into the plugin's universal bundle.
import {
  isMergedCell,
  placementsOverlap,
  syncContentToArrayOrder,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";
import {
  cloneEntryForPaste,
  entryKey,
  findAncestryPath,
  findEntry,
  findEntrySiblings,
  insertEntryAt,
  type InsertPosition,
  moveEntry,
  removeEntry,
  replaceEntryInPlace,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import { isReversedFlexLayout } from "discourse/plugins/discourse-wireframe/discourse/lib/layout/reversed-flex";
import type WireframeBlockRevealService from "./wireframe-block-reveal";
import type WireframeDropAuthorityService from "./wireframe-drop-authority";
import type WireframeLayoutQueryService from "./wireframe-layout-query";
import type WireframeMutationEngineService from "./wireframe-mutation-engine";
import type WireframeSelectionService from "./wireframe-selection";

/** The relative position of an enter-style drop against its target. */
type EnterPosition = Exclude<InsertPosition, "inside-end">;

/** Arguments for a single-entry move to a new position in the layout. */
export type MoveBlockArgs = {
  /** Composite key of the entry being moved. */
  sourceKey: string;
  /** Composite key of the destination entry, or `null` for the outlet root. */
  targetKey: string | null;
  /** Position relative to the destination entry. */
  position: EnterPosition;
  /** Outlet receiving the moved entry. */
  targetOutletName: string;
};

/** Arguments for moving an entry between two outlets (or two grids). */
type MoveAcrossOutletsArgs = {
  /** Outlet currently containing the source entry. */
  sourceOutletName: string;
  /** Outlet receiving the source entry. */
  targetOutletName: string;
  /** Composite key of the entry being moved. */
  sourceKey: string;
  /** Composite key of the destination entry, or `null` for the outlet root. */
  targetKey: string | null;
  /** Position relative to the destination entry. */
  position: EnterPosition;
  /** Whether a grid destination should assign the next available cell. */
  autoPosition?: boolean;
};

/** Arguments for inserting a freshly-synthesised entry. */
export type InsertBlockArgs = {
  /** Registered name of the block to insert. */
  blockName: string;
  /** Initial arguments copied into the new entry. */
  defaultArgs?: Record<string, unknown>;
  /** Composite key of the destination entry, or `null` for the outlet root. */
  targetKey: string | null;
  /** Position relative to the destination entry. */
  position: InsertPosition;
  /** Outlet receiving the new entry. */
  targetOutletName: string;
};

/**
 * Describes where a transform-driven insert/move lands, so the grid-related
 * helpers can resolve the destination parent.
 */
type DestinationArgs = {
  /** Entry being transformed for its destination. */
  entry: LayoutEntry;
  /** Layout containing the destination. */
  layout: LayoutEntry[];
  /** Composite key of the destination entry. */
  targetKey: string | null;
  /** Position relative to the destination entry. */
  position: InsertPosition;
};

/**
 * Owns the block-structural commands — move, duplicate, remove, insert, and
 * cross-outlet move. Each is a structural mutation routed through the engine's
 * record/publish chokepoint, so it's undoable and keeps the canvas, outline,
 * and dirty state in lockstep. The grid-placement math (cascade / fill / sync)
 * is delegated to the shared `positionEntering` lib, so this service and the
 * grid manipulator share one placement rule path without depending on each
 * other.
 *
 * A peer command service in the editor's acyclic dependency graph: it injects
 * the mutation/undo engine (records the change), the read-only layout query
 * layer (locating entries and outlets), the selection concern (which entry is
 * selected, restoring selection after a move), the drop authority (whether a
 * drop / insert is allowed), and the reveal/flash leaf (drawing the eye to a
 * freshly inserted block). It never reaches back up into the orchestrator; the orchestrator
 * keeps thin facades so its consumers (the toolbar, chrome, panels, outline,
 * drop-dispatch, grid manipulator, and keyboard shortcuts) stay unchanged.
 */
export default class WireframeBlockMutationsService extends Service {
  /** Reveals and flashes entries after insertion. */
  @service declare wireframeBlockReveal: WireframeBlockRevealService;

  /** Authorizes insertion and cross-outlet movement. */
  @service declare wireframeDropAuthority: WireframeDropAuthorityService;

  /** Records, publishes, and reverses structural mutations. */
  @service declare wireframeMutationEngine: WireframeMutationEngineService;

  /** Resolves live entries, layouts, and parent relationships. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /** Tracks and restores the selected block. */
  @service declare wireframeSelection: WireframeSelectionService;

  /**
   * Moves a block one visual position earlier among its siblings.
   *
   * @param blockKey - Composite key of the block to move.
   * @returns Whether the block moved.
   */
  moveBlockUp(blockKey: string): boolean {
    return this.#moveBlockSibling(blockKey, "up");
  }

  /**
   * Moves a block one visual position later among its siblings.
   *
   * @param blockKey - Composite key of the block to move.
   * @returns Whether the block moved.
   */
  moveBlockDown(blockKey: string): boolean {
    return this.#moveBlockSibling(blockKey, "down");
  }

  /**
   * Moves the entry identified by `sourceKey` to a new position in the
   * layout, applying the mutation to the relevant draft layer(s) and
   * recording the affected outlets so the toolbar's `isDirty`/Save and
   * `resetAll` paths pick the change up.
   *
   * Same-outlet moves are a single immutable rebuild via `moveEntry`.
   * Cross-outlet moves split into `removeEntry` from the source outlet and
   * `insertEntryAt` on the target. Both paths re-publish via
   * `_setLayoutLayer`, which preserves entry references where possible —
   * the dragged block keeps its arg edits across the move.
   *
   * Returns true on a successful structural change. Returns false (and
   * leaves layouts untouched) when the source/target can't be located, the
   * block isn't allowed in the target outlet, or the move would create a
   * self-nesting cycle (handled inside `moveEntry`).
   *
   * @param args - Source, destination, and relative placement for the move.
   */
  moveBlock({
    sourceKey,
    targetKey,
    position,
    targetOutletName,
  }: MoveBlockArgs): boolean {
    const source = this.wireframeLayoutQuery.findEntryAndOutletSync(sourceKey);
    if (!source) {
      return false;
    }
    if (!this.wireframeDropAuthority.canDropAt({ targetOutletName })) {
      return false;
    }
    // An outlet-level drop (no target block) lands INSIDE the outlet's
    // implicit root layout, never as a sibling of it — that's what keeps the
    // "single root layout per outlet" invariant intact.
    if (targetKey == null) {
      this.wireframeMutationEngine.ensureDraft(targetOutletName);
      targetKey = this.wireframeLayoutQuery.outletRootKey(targetOutletName);
      position = "inside";
    }
    const outletsAffected =
      source.outletName === targetOutletName
        ? [source.outletName]
        : [source.outletName, targetOutletName];
    return this.wireframeMutationEngine.recordStructural(
      outletsAffected,
      () => {
        const moved =
          source.outletName === targetOutletName
            ? this.#moveWithinOutlet(
                source.outletName,
                sourceKey,
                targetKey,
                position
              )
            : this.moveAcrossOutlets({
                sourceOutletName: source.outletName,
                targetOutletName,
                sourceKey,
                targetKey,
                position,
              });
        // Focus the moved block so it's the active selection afterwards — the
        // same treatment an inserted block gets. For a tabs / carousel child this
        // brings the moved tab or slide to the front via the reveal-on-select
        // path. A same-outlet move keeps the block's key; only select when the key
        // still resolves, so a cross-outlet re-key doesn't clear the selection.
        if (
          moved &&
          this.wireframeLayoutQuery.findEntryAndOutletSync(sourceKey)
        ) {
          this.wireframeSelection.restoreSelection(sourceKey);
        }
        return moved;
      }
    );
  }

  /**
   * Moves an entry from one outlet to another (or, in the same-outlet branch,
   * between two grids in the same outlet). Wraps / unwraps the entry for the
   * destination's parent (grid ↔ non-grid) and, on a grid landing, claims a
   * valid cell via the shared placement lib. Publishes both affected outlets.
   *
   * @param args - Source and destination outlet details for the move.
   */
  moveAcrossOutlets({
    sourceOutletName,
    targetOutletName,
    sourceKey,
    targetKey,
    position,
    autoPosition = true,
  }: MoveAcrossOutletsArgs): boolean {
    // SAME outlet: the removal and the insertion MUST compose on one
    // layout. Reading the source and target outlets as two separate
    // copies (the cross-outlet path below) would insert into a copy that
    // still holds the not-yet-removed source — duplicating the block. This
    // path is reached when a grid cell is dragged into a DIFFERENT grid in
    // the same outlet (e.g. via a cross-grid drop).
    if (sourceOutletName === targetOutletName) {
      const layout =
        this.wireframeLayoutQuery.readResolvedLayout(sourceOutletName);
      if (!layout) {
        return false;
      }
      const removal = removeEntry(layout, sourceKey);
      if (!removal.changed || !removal.removed) {
        return false;
      }
      const entryToInsert = this.#transformForDestination({
        entry: removal.removed,
        layout: removal.layout,
        targetKey,
        position,
      });
      const insertion = insertEntryAt(
        removal.layout,
        targetKey,
        entryToInsert,
        position
      );
      if (!insertion.changed) {
        return false;
      }
      const destGridKey = this.#destinationGridKey(
        insertion.layout,
        targetKey,
        position
      );
      const final =
        autoPosition && destGridKey
          ? positionEntering(
              insertion.layout,
              destGridKey,
              sourceKey,
              targetKey,
              position
            )
          : insertion.layout;
      this.wireframeMutationEngine.publishStructuralChange(
        sourceOutletName,
        final
      );
      return true;
    }

    const sourceLayout =
      this.wireframeLayoutQuery.readResolvedLayout(sourceOutletName);
    // Mint a draft for the target outlet if it doesn't have one yet —
    // the user may be dragging an existing block into a previously
    // empty outlet via the empty-outlet drop zone.
    const targetLayout =
      this.wireframeMutationEngine.ensureDraft(targetOutletName);
    if (!sourceLayout || !targetLayout) {
      return false;
    }
    const removal = removeEntry(sourceLayout, sourceKey);
    if (!removal.changed || !removal.removed) {
      return false;
    }
    // The moved entry may need to be wrapped (non-slot landing in a
    // grid) OR unwrapped (slot landing in a non-grid). Both cases
    // funnel through `#transformForDestination`.
    const entryToInsert = this.#transformForDestination({
      entry: removal.removed,
      layout: targetLayout,
      targetKey,
      position,
    });
    const insertion = insertEntryAt(
      targetLayout,
      targetKey,
      entryToInsert,
      position
    );
    if (!insertion.changed) {
      return false;
    }
    // A cross-outlet move is always a grid ENTER when the destination is a
    // grid: claim a valid single cell and sync the grid's declared size.
    const destGridKey = this.#destinationGridKey(
      insertion.layout,
      targetKey,
      position
    );
    const targetFinal =
      autoPosition && destGridKey
        ? positionEntering(
            insertion.layout,
            destGridKey,
            sourceKey,
            targetKey,
            position
          )
        : insertion.layout;
    // Publish both outlets in one go — the editor service holds both as
    // session-draft layers, so each `_setLayoutLayer` call only re-resolves
    // its own outlet's chain.
    this.wireframeMutationEngine.publishStructuralChange(
      sourceOutletName,
      removal.layout
    );
    this.wireframeMutationEngine.publishStructuralChange(
      targetOutletName,
      targetFinal
    );
    return true;
  }

  /**
   * Inserts `count` fresh clones of the given block immediately after it in
   * the layout. Used by the block toolbar's `Duplicate` button (`count = 1`)
   * and its "duplicate ×N" menu. All clones land in a single structural
   * transaction, so the whole batch is one undo step. The clones are identical,
   * so their relative order among themselves is irrelevant.
   *
   * @param blockKey - Composite key of the block to duplicate.
   * @param count - How many clones to insert (clamped to >= 1).
   */
  duplicateBlock(blockKey: string, count: number = 1): boolean {
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(blockKey);
    if (!located) {
      return false;
    }
    const copies = Math.max(1, Math.floor(count));
    return this.wireframeMutationEngine.recordStructural(
      [located.outletName],
      () => {
        let layout = this.wireframeLayoutQuery.readResolvedLayout(
          located.outletName
        );
        if (!layout) {
          return false;
        }
        let changed = false;
        for (let i = 0; i < copies; i++) {
          const insertion = insertEntryAt(
            layout,
            blockKey,
            cloneEntryForPaste(located.entry),
            "after"
          );
          if (insertion.changed) {
            layout = insertion.layout;
            changed = true;
          }
        }
        if (!changed) {
          return false;
        }
        this.wireframeMutationEngine.publishStructuralChange(
          located.outletName,
          layout
        );
        return true;
      }
    );
  }

  /**
   * Inserts a freshly-synthesised entry at the given position in the
   * target outlet. Mirrors `moveBlock`'s shape but takes a `blockName`
   * (and a defaultArgs payload from the palette) instead of a source key,
   * since there's no existing entry to lift from elsewhere.
   *
   * The new entry is minted as a plain `{block: blockName, args}` POJO;
   * `assignStableKeys` (invoked by `_setLayoutLayer` inside
   * `publishStructuralChange`) stamps a `__stableKey` when the draft
   * layer is published, so the rest of the editor (selection, drag,
   * outline) can address it by key from the next render onwards.
   *
   * Returns false (and leaves the layout untouched) when the target
   * outlet doesn't have a resolvable layout, the block isn't allowed in
   * that outlet, or the insert otherwise no-ops.
   *
   * @param args - Block definition and destination for the insert.
   */
  insertBlock({
    blockName,
    defaultArgs = {},
    targetKey,
    position,
    targetOutletName,
  }: InsertBlockArgs): boolean {
    if (
      !this.wireframeDropAuthority.canInsertBlockAt({
        blockName,
        targetOutletName,
      })
    ) {
      return false;
    }
    return this.wireframeMutationEngine.recordStructural(
      [targetOutletName],
      () => {
        // Mint a draft on the fly for outlets the user is populating from
        // scratch (no published layout → `#materializeAllDrafts` skipped
        // them on `enter()`). The empty-outlet drop zone needs this.
        const layout =
          this.wireframeMutationEngine.ensureDraft(targetOutletName);
        if (!layout) {
          return false;
        }
        // An outlet-level insert (no target block) lands INSIDE the outlet's
        // implicit root layout, preserving the single-root invariant. Resolved
        // after `ensureDraft` so a freshly-seeded outlet has its root key.
        if (targetKey == null) {
          targetKey = this.wireframeLayoutQuery.outletRootKey(targetOutletName);
          position = "inside";
        }
        // Mint a fresh entry. Spread the defaults so future mutations don't
        // bleed back into the caller's object. Args left missing here get
        // filled in from the block's schema `default:` values via
        // `applyArgDefaults` at render time.
        const fresh: LayoutEntry = {
          block: blockName,
          args: { ...defaultArgs },
        };
        // A container that forces its children to one kind (e.g. tabs → `layout`)
        // must never be empty — it would be invalid AND have no first tab to fill.
        // Seed it with one child of that kind so dropping the block lands a ready
        // first panel (and the block's "add" affordance grows it from there).
        const seedKind = this.#implicitChildKind(blockName);
        if (seedKind) {
          fresh.children = [{ block: seedKind, args: {} }];
        }
        // Annotate with `containerArgs.grid` defaults when the destination
        // parent is a `wf:layout` in grid mode — that's the placement
        // namespace the grid layout reads to position each direct child.
        const entry = this.#annotateForDestination({
          entry: fresh,
          layout,
          targetKey,
          position,
        });
        const insertion = insertEntryAt(layout, targetKey, entry, position);
        if (!insertion.changed) {
          return false;
        }
        this.wireframeMutationEngine.publishStructuralChange(
          targetOutletName,
          insertion.layout
        );
        // Auto-select the freshly inserted block so the inspector immediately
        // shows its form (and, for a `wf:layout` in grid mode, the grid overlay
        // mounts without the author having to click first).
        // `publishStructuralChange` runs `assignStableKeys`, so `entry`
        // has a `__stableKey` by the time this fires.
        this.selectInsertedEntry(entry);
        return true;
      }
    );
  }

  /**
   * Appends a fresh child of a container's declared implicit-child kind to the
   * end of its children, then selects it. Drives the "add" affordance an
   * implicit-child-kind container renders (e.g. a tabbed container's trailing
   * "+" on the strip): the new panel is the sole `childBlocks` kind (a `layout`),
   * so it arrives ready to fill with a rich layout. No-ops for a key that isn't
   * such a container.
   *
   * @param containerKey - The implicit-child-kind container's key.
   */
  appendImplicitChild(containerKey: string): boolean {
    const located =
      this.wireframeLayoutQuery.findEntryAndOutletSync(containerKey);
    if (!located) {
      return false;
    }
    const kind = this.#implicitChildKind(located.entry.block);
    if (!kind) {
      return false;
    }
    return this.insertBlock({
      blockName: kind,
      targetKey: containerKey,
      position: "inside-end",
      targetOutletName: located.outletName,
    });
  }

  /**
   * Removes the block matching `blockKey` from whichever outlet currently
   * holds it. Used by the floating block toolbar, the inspector's recovery
   * actions, the keyboard Delete / Backspace path, and cut (Cmd+X). The
   * implicit outlet root is a no-op (deleting it would remove the whole page
   * region). Routes through `publishStructuralChange` so the bookkeeping
   * (edited-outlets, structural-version, isDirty signal) matches a drag-driven
   * move.
   *
   * @param blockKey - Composite key of the block to remove.
   * @returns true on success
   */
  removeBlock(blockKey: string): boolean {
    // The implicit root layout IS the outlet; deleting it would remove the
    // whole page region. Block-level delete is a no-op on the root — the
    // toolbar and inspector already hide the affordance, and this guard
    // also closes the keyboard (Delete / Backspace) and cut (Cmd+X) paths
    // that reach `removeBlock` directly.
    if (this.wireframeLayoutQuery.isOutletRoot(blockKey)) {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(blockKey);
    if (!located) {
      return false;
    }
    return this.wireframeMutationEngine.recordStructural(
      [located.outletName],
      () => {
        const layout = this.wireframeLayoutQuery.readResolvedLayout(
          located.outletName
        );
        if (!layout) {
          return false;
        }
        const result = this.#removeEntryFromLayout(
          layout,
          blockKey,
          located.entry
        );
        if (!result.changed) {
          return false;
        }
        if (this.wireframeSelection.selectedBlockKey === blockKey) {
          this.wireframeSelection.selectBlock(null);
        }
        this.wireframeMutationEngine.publishStructuralChange(
          located.outletName,
          result.layout
        );
        return true;
      }
    );
  }

  /**
   * Removes several blocks in a single structural transaction, so the whole
   * batch is one undo step. Used by the multi-selection's bulk delete (the
   * inspector panel + the Delete shortcut). Outlet roots are skipped; a
   * container and one of its descendants both being selected is safe — once the
   * container is gone the descendant key simply no longer matches.
   *
   * @param keys - Composite keys of the blocks to remove.
   * @returns Whether anything was removed.
   */
  removeBlocks(keys: readonly string[]): boolean {
    const located = keys
      .filter((key) => !this.wireframeLayoutQuery.isOutletRoot(key))
      .flatMap((key) => {
        const found = this.wireframeLayoutQuery.findEntryAndOutletSync(key);
        return found ? [{ key, ...found }] : [];
      });
    if (located.length === 0) {
      return false;
    }
    const outletNames = [...new Set(located.map((l) => l.outletName))];
    return this.wireframeMutationEngine.recordStructural(outletNames, () => {
      let anyChanged = false;
      for (const outletName of outletNames) {
        let layout = this.wireframeLayoutQuery.readResolvedLayout(outletName);
        if (!layout) {
          continue;
        }
        let outletChanged = false;
        for (const { key, entry } of located.filter(
          (l) => l.outletName === outletName
        )) {
          const result = this.#removeEntryFromLayout(layout, key, entry);
          if (result.changed) {
            layout = result.layout;
            outletChanged = true;
          }
        }
        if (outletChanged) {
          this.wireframeMutationEngine.publishStructuralChange(
            outletName,
            layout
          );
          anyChanged = true;
        }
      }
      if (anyChanged) {
        this.wireframeSelection.selectBlock(null);
      }
      return anyChanged;
    });
  }

  /**
   * Looks up the composite key of a freshly inserted entry (after
   * `publishStructuralChange` has assigned its `__stableKey`) and routes
   * through `restoreSelection` so the editor's selection state — and the
   * inspector — points at it. No-ops if the entry isn't yet resolvable
   * (paranoia: the assign should always succeed for a just-inserted entry).
   *
   * @param entry - The original entry reference passed into the layout; will
   *   have its `__stableKey` set by the publish step.
   */
  selectInsertedEntry(entry: LayoutEntry): void {
    const key = entryKey(entry);
    if (!key) {
      return;
    }
    this.wireframeSelection.restoreSelection(key);
    // Flash the freshly inserted block so the eye lands on it, the same way
    // outline selection does.
    this.wireframeBlockReveal.flash(key);
  }

  /**
   * Shared body for the floating block toolbar's move up / down buttons.
   * Looks up the selected entry's siblings and computes a `moveBlock` call
   * against the previous / next sibling in the direction the author SEES.
   *
   * A reversed flex parent (stack / row with `reverse`) renders its children
   * in reverse, so a visual "up" is a move toward a LATER persisted index (and
   * vice versa). The visual direction is mapped to the persisted one before
   * picking the target sibling, so the buttons always move the block the way
   * the author expects on screen.
   *
   * Returns `false` (no-op) when the block is already first / last (visually)
   * in its parent, when no block is selected, or when the move is rejected.
   *
   * @param blockKey - Composite key of the block to move.
   * @param visualDirection - Direction the author expects on screen.
   */
  #moveBlockSibling(blockKey: string, visualDirection: "up" | "down"): boolean {
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(blockKey);
    if (!located) {
      return false;
    }
    const layout = this.wireframeLayoutQuery.readResolvedLayout(
      located.outletName
    );
    if (!layout) {
      return false;
    }
    const sibs = findEntrySiblings(layout, blockKey);
    if (!sibs) {
      return false;
    }
    const reversed = isReversedFlexLayout(
      this.wireframeLayoutQuery.findEntryParent(blockKey)?.args
    );
    const goEarlier = reversed
      ? visualDirection === "down"
      : visualDirection === "up";

    if (goEarlier) {
      if (sibs.index === 0) {
        return false;
      }
      return this.moveBlock({
        sourceKey: blockKey,
        targetKey: entryKey(sibs.siblings[sibs.index - 1]),
        position: "before",
        targetOutletName: located.outletName,
      });
    }
    if (sibs.index >= sibs.siblings.length - 1) {
      return false;
    }
    return this.moveBlock({
      sourceKey: blockKey,
      targetKey: entryKey(sibs.siblings[sibs.index + 1]),
      position: "after",
      targetOutletName: located.outletName,
    });
  }

  /**
   * Moves an entry within one outlet and applies destination grid semantics.
   *
   * @param outletName - Outlet containing both source and destination.
   * @param sourceKey - Composite key of the entry to move.
   * @param targetKey - Destination key, or `null` for the outlet root.
   * @param position - Placement relative to the destination.
   * @param options - Grid-order synchronization options.
   * @returns Whether the entry moved.
   */
  #moveWithinOutlet(
    outletName: string,
    sourceKey: string,
    targetKey: string | null,
    position: EnterPosition,
    {
      syncGridOrder = true,
      placeEntering = true,
    }: {
      /** Whether same-grid children should follow persisted array order. */
      syncGridOrder?: boolean;
      /** Whether an entering entry should claim a destination grid cell. */
      placeEntering?: boolean;
    } = {}
  ): boolean {
    const layout = this.wireframeLayoutQuery.readResolvedLayout(outletName);
    if (!layout) {
      return false;
    }
    const sourceEntry = findEntry(layout, sourceKey);
    if (!sourceEntry) {
      return false;
    }

    // Classify the move against the destination grid (if any). A grid
    // ENTER is a move whose destination grid is NOT the source's current
    // parent; a same-grid move keeps the source under the same grid.
    const sourceParentKey = this.#parentKeyOf(layout, sourceKey);
    const destGridKey = this.#destinationGridKey(layout, targetKey, position);
    const enteringGrid = destGridKey != null && destGridKey !== sourceParentKey;
    const sameGrid = destGridKey != null && destGridKey === sourceParentKey;
    const besideCell =
      (position === "before" || position === "after") &&
      targetKey != null &&
      targetKey !== destGridKey;

    // A drop BESIDE a cell — whether the block is entering or already in
    // this grid — cascades the row to make room (R2: shift right, grow a
    // column when the row is full). Same-grid cascades in place: grids
    // position by `containerArgs.grid`, not array order, so no remove /
    // insert is needed. `positionEntering` (the shared grid-placement lib)
    // routes through the decider, so same-grid and entering cascades share one
    // rule path.
    // `placeEntering: false` callers set an exact cell themselves and opt out.
    if (sameGrid && besideCell && placeEntering) {
      this.wireframeMutationEngine.publishStructuralChange(
        outletName,
        positionEntering(layout, destGridKey, sourceKey, targetKey, position)
      );
      return true;
    }

    // Other same-grid moves (dropped on the grid container itself, not a
    // specific cell): keep the reading-order reflow so the array order
    // drives the visual order.
    if (sameGrid) {
      const result = moveEntry(layout, sourceKey, targetKey, position);
      if (!result.changed) {
        return false;
      }
      this.wireframeMutationEngine.publishStructuralChange(
        outletName,
        syncGridOrder
          ? this.#syncDestGridOrder(result.layout, targetKey, position)
          : result.layout
      );
      return true;
    }

    // Any other move: the destination may require resetting the grid bag
    // (entering a grid — a carried span is discarded) OR stripping it
    // (leaving a grid). Both substitute the entry, so a remove + insert is
    // needed — which also guarantees the source is removed.
    const transformed = this.#transformForDestination({
      entry: sourceEntry,
      layout,
      targetKey,
      position,
    });
    if (transformed !== sourceEntry) {
      const removal = removeEntry(layout, sourceKey);
      if (!removal.changed || !removal.removed) {
        return false;
      }
      const insertion = insertEntryAt(
        removal.layout,
        targetKey,
        transformed,
        position
      );
      if (!insertion.changed) {
        return false;
      }
      // A block entering a grid claims a valid single cell (next free
      // slot, growing a row when full) and the grid's declared size is
      // synced to usage — never the array-order reflow, which is for
      // reorders within a grid. Callers that set an exact cell afterward
      // (the precise cell-drop path) opt out via `placeEntering: false`.
      const finalLayout =
        enteringGrid && placeEntering
          ? positionEntering(
              insertion.layout,
              destGridKey,
              sourceKey,
              targetKey,
              position
            )
          : insertion.layout;
      this.wireframeMutationEngine.publishStructuralChange(
        outletName,
        finalLayout
      );
      return true;
    }
    const result = moveEntry(layout, sourceKey, targetKey, position);
    if (!result.changed) {
      return false;
    }
    this.wireframeMutationEngine.publishStructuralChange(
      outletName,
      syncGridOrder
        ? this.#syncDestGridOrder(result.layout, targetKey, position)
        : result.layout
    );
    return true;
  }

  /**
   * The composite key of the `wf:layout` (grid mode) that would CONTAIN an
   * entry dropped at `(targetKey, position)`, or `null` when the
   * destination isn't a grid. "inside" targets the container itself;
   * "before" / "after" target a sibling, so the grid is its parent.
   *
   * @param layout - Layout containing the proposed destination.
   * @param targetKey - Composite key anchoring the destination.
   * @param position - Relative placement against the target.
   */
  #destinationGridKey(
    layout: LayoutEntry[],
    targetKey: string | null,
    position: EnterPosition
  ): string | null {
    const parent = this.#destinationParentEntry({
      layout,
      targetKey,
      position,
    });
    return this.wireframeLayoutQuery.isGridContainer(parent)
      ? entryKey(parent)
      : null;
  }

  /**
   * When a within-outlet move lands in a grid layout, re-derive that
   * grid's content placements from the new array order (see
   * `syncContentToArrayOrder`) so reordering rows in the outline moves
   * blocks in the grid rather than just shuffling an invisible array.
   * A no-op for stack / row destinations, where array order already IS
   * the visual order.
   *
   * @param layout - Layout after the entry move.
   * @param targetKey - The move's target (sibling for before / after, the
   *   container itself for inside).
   * @param position - Relative placement against the target.
   * @returns The layout, with the destination grid's content resynced when
   *   applicable.
   */
  #syncDestGridOrder(
    layout: LayoutEntry[],
    targetKey: string | null,
    position: EnterPosition
  ): LayoutEntry[] {
    const gridKey =
      position === "inside" ? targetKey : this.#parentKeyOf(layout, targetKey);
    if (!gridKey) {
      return layout;
    }
    const grid = findEntry(layout, gridKey);
    if (!grid || grid.args?.mode !== "grid") {
      return layout;
    }
    const result = replaceEntryInPlace(layout, gridKey, {
      ...grid,
      children: syncContentToArrayOrder(grid.children ?? []),
    });
    return result.changed ? result.layout : layout;
  }

  /**
   * The composite key of `key`'s parent entry, or `null` when `key` is
   * top-level (no enclosing container) or can't be found.
   *
   * @param layout - Layout tree to search.
   * @param key - Composite key whose parent should be resolved.
   */
  #parentKeyOf(layout: LayoutEntry[], key: string | null): string | null {
    if (!key) {
      return null;
    }
    const chain = findAncestryPath(layout, key);
    if (!chain || chain.length < 2) {
      return null;
    }
    return entryKey(chain[chain.length - 2]);
  }

  /**
   * Resolves the entry that will contain the inserted / moved entry.
   *
   *  - "inside" position → `targetKey` is the parent.
   *  - "before" / "after" → the entry one level above `targetKey`.
   *  - `targetKey === null` → outlet root (no block-level parent).
   *
   * Returns `null` for the outlet-root case.
   *
   * @param args - Layout and relative destination to resolve.
   */
  #destinationParentEntry({
    layout,
    targetKey,
    position,
  }: Omit<DestinationArgs, "entry">): LayoutEntry | null {
    if (!targetKey) {
      return null;
    }
    if (position === "inside") {
      return findEntry(layout, targetKey);
    }
    const path = findAncestryPath(layout, targetKey);
    if (!path || path.length < 2) {
      return null;
    }
    return path[path.length - 2];
  }

  /**
   * Annotates an entry with `containerArgs.grid` defaults when its
   * destination parent is a `wf:layout` in `grid` mode. The grid
   * namespace carries CSS Grid placement (`column` / `row` / `align` /
   * `justify`) so the layout can position each direct child.
   *
   * Returns the entry to insert. When no annotation is needed
   * (destination isn't a grid) returns the entry unchanged.
   *
   * A block ENTERING a grid always has its `grid` namespace reset to a
   * neutral `auto / auto` cell — any span/placement it carried from a
   * previous grid is discarded, so it can never drag a stale wide span
   * into a smaller grid. The concrete cell it occupies is assigned by the
   * caller (`positionEntering`) once the children + dimensions are known;
   * this only guarantees the foreign placement is gone. The returned
   * object is always a fresh reference, so the caller's
   * `transformed !== sourceEntry` check routes through remove + insert
   * (which guarantees the source is removed). Same-grid reorders never
   * reach here — the movers handle those before transforming.
   *
   * @param args - Entry and destination against which it should be annotated.
   */
  #annotateForDestination({
    entry,
    layout,
    targetKey,
    position,
  }: DestinationArgs): LayoutEntry {
    if (!entry) {
      return entry;
    }
    const parent = this.#destinationParentEntry({
      layout,
      targetKey,
      position,
    });
    const enteringGrid = this.wireframeLayoutQuery.isGridContainer(parent);

    if (enteringGrid) {
      // Overwrite (don't merge) the grid bag so a carried span is dropped.
      return {
        ...entry,
        containerArgs: {
          ...(entry.containerArgs ?? {}),
          grid: {
            column: "auto",
            row: "auto",
            align: "stretch",
            justify: "stretch",
          },
        },
      };
    }

    // Leaving any grid: strip the `grid` namespace; clear `containerArgs`
    // entirely if no other namespaces remain so serialised output stays
    // clean and core's `validateOrphanContainerArgs` doesn't warn.
    if (!entry.containerArgs?.grid) {
      return entry;
    }
    const remaining = { ...entry.containerArgs };
    delete remaining.grid;
    if (Object.keys(remaining).length === 0) {
      const stripped = { ...entry };
      delete stripped.containerArgs;
      return stripped;
    }
    return { ...entry, containerArgs: remaining };
  }

  /**
   * Single entry point that picks between annotating and stripping
   * `containerArgs.grid` based on the entry's current shape and the
   * destination's parent. Returns the entry-to-insert; entry identity
   * is preserved when only the bag changes, so callers can rely on
   * `moveEntry` rather than a `remove + insert` round-trip.
   *
   * @param args - Entry and destination whose container metadata should change.
   */
  #transformForDestination({
    entry,
    layout,
    targetKey,
    position,
  }: DestinationArgs): LayoutEntry {
    return this.#annotateForDestination({ entry, layout, targetKey, position });
  }

  /**
   * Removes a single entry from `layout` by key, preserving a multi-cell grid
   * placement as an empty merged-cell entry (keeps the author's layout shape —
   * a hero spanning 3 columns, a sidebar rail — intact even when its content is
   * removed); single-cell entries are removed outright. Returns the
   * `{ layout, changed }` result without publishing.
   *
   * @param layout - Layout tree containing the entry.
   * @param key - Composite key of the entry to remove.
   * @param entry - The located entry (for its `containerArgs`).
   */
  #removeEntryFromLayout(
    layout: LayoutEntry[],
    key: string,
    entry: LayoutEntry
  ): {
    /** Layout after the requested removal. */
    layout: LayoutEntry[];
    /** Whether the layout changed. */
    changed: boolean;
  } {
    return this.#shouldRestoreAsCell(layout, entry, key)
      ? replaceEntryInPlace(layout, key, {
          block: LAYOUT_MERGED_CELL_BLOCK,
          containerArgs: entry.containerArgs,
        })
      : removeEntry(layout, key);
  }

  /**
   * Returns true when removing `entry` from `layout` should leave an
   * empty merged-cell entry at the same position instead of clearing
   * the cell entirely. All four conditions must hold:
   *
   *   1. The entry isn't already a merged cell — deleting an empty cell
   *      is the author saying "I don't want this region", not
   *      "regenerate one".
   *   2. The placement spans more than one cell (column span > 1 OR
   *      row span > 1). Single-cell positions are already discoverable
   *      via the grid overlay's auto-empty cell rendering; we only
   *      need an explicit cell entry when the rect is too large for
   *      the auto-detection to reconstruct.
   *   3. The placement fits within the parent grid's `columns` /
   *      `rows`. Restoring a cell that overflows the grid would just
   *      produce another `--out-of-bounds` warning.
   *   4. The placement doesn't overlap any sibling's placement.
   *      Stacking two cells at the same rect is already a
   *      malformed state; we don't want to perpetuate it.
   *
   * @param layout - Layout tree containing the entry and its parent grid.
   * @param entry - Entry being removed from the layout.
   * @param entryKeyValue - The entry's composite key.
   */
  #shouldRestoreAsCell(
    layout: LayoutEntry[],
    entry: LayoutEntry,
    entryKeyValue: string
  ): boolean {
    if (!entry || isMergedCell(entry)) {
      return false;
    }
    const placement = parsePlacement(entry.containerArgs);
    const cs = placement.column.start;
    const ce = placement.column.end;
    const rs = placement.row.start;
    const re = placement.row.end;
    if (cs == null || ce == null || rs == null || re == null) {
      return false;
    }
    const colSpan = ce - cs;
    const rowSpan = re - rs;
    if (colSpan <= 1 && rowSpan <= 1) {
      return false;
    }
    // Walk to the parent grid via the ancestry chain. The immediate
    // parent of the entry is at the second-to-last position; its
    // `args.columns` / `args.rows` are the bounds we check against.
    const chain = findAncestryPath(layout, entryKeyValue);
    if (!chain || chain.length < 2) {
      return false;
    }
    const parent = chain[chain.length - 2];
    const cols = Number(parent.args?.columns);
    const rows = Number(parent.args?.rows);
    if (!Number.isFinite(cols) || !Number.isFinite(rows)) {
      return false;
    }
    if (cs < 1 || rs < 1 || ce > cols + 1 || re > rows + 1) {
      return false;
    }
    // Sibling overlap check. The entry itself is in `parent.children`;
    // skip it during the walk.
    for (const sibling of parent.children ?? []) {
      if (sibling === entry) {
        continue;
      }
      if (placementsOverlap(placement, parsePlacement(sibling.containerArgs))) {
        return false;
      }
    }
    return true;
  }

  /**
   * The sole block kind a container forces every direct child to be (e.g. a
   * tabbed container → `layout`), or null when the block isn't such a container.
   * The kind must itself be a container, so a non-conforming child can be
   * wrapped in it and an empty container can be seeded with it.
   *
   * @param blockRef - The container's block ref.
   */
  #implicitChildKind(blockRef: LayoutEntry["block"]): string | null {
    const childBlocks =
      this.wireframeLayoutQuery.lookupBlockMetadata(blockRef)?.childBlocks;
    if (childBlocks?.length !== 1) {
      return null;
    }
    const kind = childBlocks[0];
    return this.wireframeLayoutQuery.lookupBlockMetadata(kind)?.isContainer
      ? kind
      : null;
  }
}
