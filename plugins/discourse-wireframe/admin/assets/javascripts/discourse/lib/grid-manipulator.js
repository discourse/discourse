// @ts-check
import {
  DEFAULT_GRID_COLUMNS,
  DEFAULT_GRID_ROWS,
  gridDimensions,
  LAYOUT_MERGED_CELL_BLOCK,
  normalizeFractions,
  parsePlacement,
} from "discourse/blocks";
import {
  decideGridDrop,
  GRID_DROP_ACTIONS,
  GRID_DROP_GESTURES,
  rectIsFree,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-drop";
import {
  formatTrack,
  isMergedCell,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";
import {
  entryKey,
  findEntry,
  insertEntryAt,
  removeEntry,
  replaceEntryContainerArgs,
  replaceEntryInPlace,
} from "./mutate-layout";

/**
 * Owns block placement into a grid `wf:layout` so the drop rules can't be
 * bypassed. Drops are described, not chosen: callers hand a request to a
 * single entry point (`drop`) that routes it through `decideGridDrop` (the
 * rule chokepoint) and into private executors. The placement-adjacent
 * deterministic ops live here too — resizing a cell (`resizeSlot`) or the
 * column tracks (`resizeColumns`), and filling an explicit merged cell
 * placeholder (`placeInCell` / `moveIntoCell`) — but those target an
 * explicit rect, so they don't consult the decider. (Whole-grid template /
 * dimension reshaping stays on the service as its own subsystem.)
 *
 * The editor service instantiates one of these and delegates to it, the same
 * way it does for `InlineEditState` / `IconEditState`. The manipulator calls
 * back into the service for outlet resolution, undo wrapping, and publishing;
 * the pure layout transforms below need none of that and operate on plain
 * layout arrays.
 */
export default class GridManipulator {
  /**
   * @param {Object} service - The editor (`wireframe`) service. Held for the
   *   outlet / undo / publish primitives the drop pipeline needs.
   */
  constructor(service) {
    this.service = service;
  }

  /**
   * The single entry point for dropping a block into a grid. Callers
   * describe the drop — the target grid, the gesture (into / beside /
   * generic) and its anchor, and the source — and this routes it through
   * `decideGridDrop` (the rule chokepoint) and into the matching private
   * executor. There is no other way to place into a grid, so a drop can't
   * skip the rules.
   *
   * The whole operation is one structural-undo entry. Returns false (no
   * commit) when the grid / source can't be resolved or the decision is a
   * no-op (e.g. a palette block onto an occupied cell).
   *
   * @param {{
   *   targetGridKey: string,
   *   gesture: string,
   *   cell?: {column: number, row: number}|null,
   *   anchorKey?: string|null,
   *   direction?: "left"|"right"|"up"|"down",
   *   shift?: boolean,
   *   source: {
   *     kind: "new"|"existing",
   *     key?: string|null,
   *     blockName?: string|null,
   *     defaultArgs?: Object|null,
   *   },
   * }} request
   * @returns {boolean}
   */
  drop(request) {
    const svc = this.service;
    const {
      targetGridKey,
      gesture,
      cell,
      anchorKey,
      direction,
      shift,
      source,
    } = request;
    const grid = svc.layoutQuery.findEntryAndOutletSync(targetGridKey);
    if (!grid || !svc.layoutQuery.isGridContainer(grid.entry)) {
      return false;
    }
    // Resolve an existing source up front (palette sources have no entry
    // yet). A cross-outlet source widens the affected-outlet set so undo
    // restores both sides atomically.
    const sourceLocated =
      source?.kind === "existing" && source.key
        ? svc.layoutQuery.findEntryAndOutletSync(source.key)
        : null;
    if (source?.kind === "existing" && !sourceLocated) {
      return false;
    }
    if (source?.kind === "new") {
      if (
        !source.blockName ||
        !svc.dropAuthority.canInsertBlockAt({
          blockName: source.blockName,
          targetOutletName: grid.outletName,
        })
      ) {
        return false;
      }
    }
    const outletsAffected =
      sourceLocated && sourceLocated.outletName !== grid.outletName
        ? [sourceLocated.outletName, grid.outletName]
        : [grid.outletName];

    return svc.recordStructural(outletsAffected, () => {
      const layout = svc.layoutQuery.readResolvedLayout(grid.outletName);
      const gridEntry = layout && findEntry(layout, targetGridKey);
      if (!gridEntry) {
        return false;
      }
      const decision = decideGridDrop({
        children: gridEntry.children ?? [],
        declared: {
          columns: Number(gridEntry.args?.columns ?? DEFAULT_GRID_COLUMNS),
          rows: Number(gridEntry.args?.rows ?? DEFAULT_GRID_ROWS),
        },
        source: { kind: source.kind, key: source.key ?? null },
        drop: { gesture, cell, anchorKey, direction, shift },
      });
      switch (decision.action) {
        case GRID_DROP_ACTIONS.FILL:
        case GRID_DROP_ACTIONS.APPEND:
        case GRID_DROP_ACTIONS.CASCADE:
          return this.#place(
            grid.outletName,
            targetGridKey,
            source,
            sourceLocated,
            decision
          );
        case GRID_DROP_ACTIONS.SWAP:
          return this.#swap(grid.outletName, source, sourceLocated, decision);
        case GRID_DROP_ACTIONS.REPLACE:
          return this.#replace(
            grid.outletName,
            targetGridKey,
            source,
            sourceLocated,
            decision
          );
        default:
          return false;
      }
    });
  }

  /**
   * Moves an existing block onto an empty merged cell, removing the source and
   * replacing the placeholder with the moved block's data — the block adopts
   * the cell's `containerArgs.grid` (and its span / identity) so it lands at
   * the cell's exact rect. Same-outlet only for now. A deterministic
   * replace-in-place against a chosen placeholder, not a decided placement.
   *
   * @param {{sourceKey: string, cellKey: string}} args
   * @returns {boolean}
   */
  moveIntoCell({ sourceKey, cellKey }) {
    const svc = this.service;
    if (sourceKey === cellKey) {
      return false;
    }
    const sourceLocated = svc.layoutQuery.findEntryAndOutletSync(sourceKey);
    const cellLocated = svc.layoutQuery.findEntryAndOutletSync(cellKey);
    if (!sourceLocated || !cellLocated) {
      return false;
    }
    if (sourceLocated.outletName !== cellLocated.outletName) {
      return false;
    }
    if (!isMergedCell(cellLocated.entry)) {
      return false;
    }
    return svc.recordStructural([cellLocated.outletName], () => {
      const layout = svc.layoutQuery.readResolvedLayout(cellLocated.outletName);
      if (!layout) {
        return false;
      }
      const removal = removeEntry(layout, sourceKey);
      if (!removal.changed || !removal.removed) {
        return false;
      }
      // Drop the source's `__stableKey` — the cell's stableKey wins
      // (`replaceEntryInPlace` keeps the matched entry's stableKey), the
      // right identity for re-render continuity at the cell's position.
      const { __stableKey, ...sourceData } = removal.removed;
      void __stableKey;
      const movedEntry = {
        ...sourceData,
        containerArgs: cellLocated.entry.containerArgs,
      };
      const replacement = replaceEntryInPlace(
        removal.layout,
        cellKey,
        movedEntry
      );
      if (!replacement.changed) {
        return false;
      }
      svc.publishStructuralChange(cellLocated.outletName, replacement.layout);
      return true;
    });
  }

  /**
   * Replaces an empty merged-cell placeholder with a fresh block. The new
   * entry inherits the cell's `containerArgs.grid`, so it lands at the same
   * (possibly spanning) rect. A deterministic replace-in-place against a
   * chosen placeholder, not a decided placement.
   *
   * @param {{cellKey: string, blockName: string, defaultArgs?: Object}} args
   * @returns {boolean}
   */
  placeInCell({ cellKey, blockName, defaultArgs = {} }) {
    const svc = this.service;
    const located = svc.layoutQuery.findEntryAndOutletSync(cellKey);
    if (!located || !isMergedCell(located.entry)) {
      return false;
    }
    if (
      !svc.dropAuthority.canInsertBlockAt({
        blockName,
        targetOutletName: located.outletName,
      })
    ) {
      return false;
    }
    return svc.recordStructural([located.outletName], () => {
      const layout = svc.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const newEntry = {
        block: blockName,
        args: { ...defaultArgs },
        containerArgs: located.entry.containerArgs,
      };
      const result = replaceEntryInPlace(layout, cellKey, newEntry);
      if (!result.changed) {
        return false;
      }
      svc.publishStructuralChange(located.outletName, result.layout);
      // `replaceEntryInPlace` clones `newEntry` (inheriting the cell's stable
      // key) into the layout; select that placed clone, since the original
      // `newEntry` never receives a stable key.
      svc.selectInsertedEntry(result.entry ?? newEntry);
      return true;
    });
  }

  /**
   * Creates an empty merged cell spanning `rect` (CSS Grid line numbers, end
   * exclusive) inside a grid — the one way to turn blank grid space into a
   * persisted spanning region. It validates the rect through the shared
   * `rectIsFree` occupancy primitive (refusing on any overlap, the same verdict
   * the drop decider would reach for that region), inserts a merged-cell entry
   * at the rect, then grows the grid's declared size to fit. A direct spanning
   * insert, not a decided placement — the decider only ever lands a 1×1, so it
   * can't express a merge; routing through the shared primitive keeps the
   * no-overlap invariant single-sourced all the same.
   *
   * @param {{
   *   gridKey: string,
   *   rect: {column: {start: number, end: number}, row: {start: number, end: number}},
   * }} args
   * @returns {boolean}
   */
  mergeCells({ gridKey, rect }) {
    const svc = this.service;
    const located = svc.layoutQuery.findEntryAndOutletSync(gridKey);
    if (!located) {
      return false;
    }
    return svc.recordStructural([located.outletName], () => {
      const layout = svc.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const grid = findEntry(layout, gridKey);
      if (!grid) {
        return false;
      }
      // Refuse a merge that would overlap existing content. Occupancy is
      // single-sourced through `rectIsFree`, so this is the same verdict the
      // decider reaches — no second, divergent overlap rule.
      if (!rectIsFree(grid.children ?? [], rect)) {
        return false;
      }
      const cellEntry = {
        block: LAYOUT_MERGED_CELL_BLOCK,
        args: {},
        containerArgs: {
          grid: {
            column: formatTrack(rect.column),
            row: formatTrack(rect.row),
            align: "stretch",
            justify: "stretch",
          },
        },
      };
      const insertion = insertEntryAt(layout, gridKey, cellEntry, "inside");
      if (!insertion.changed) {
        return false;
      }
      // A merge can extend past the declared tracks (it's a create, like a
      // drop), so grow declared to fit — keeping effective ≤ declared.
      const synced = this.syncDeclaredToUsage(insertion.layout, gridKey);
      svc.publishStructuralChange(located.outletName, synced);
      svc.selectInsertedEntry(cellEntry);
      return true;
    });
  }

  /**
   * Dissolves an empty merged cell back into blank space: removes its entry so
   * the now-uncovered base cells are re-derived as single 1×1 empties (single
   * cells are never persisted — the grid overlay surfaces them geometrically).
   * The grid's declared size is intentionally left untouched: a removal never
   * grows usage, and shrinking would collapse rows / columns the author still
   * wants held open. The inverse of `mergeCells`.
   *
   * @param {{cellKey: string}} args
   * @returns {boolean}
   */
  splitCell({ cellKey }) {
    const svc = this.service;
    const located = svc.layoutQuery.findEntryAndOutletSync(cellKey);
    if (!located || !isMergedCell(located.entry)) {
      return false;
    }
    return svc.recordStructural([located.outletName], () => {
      const layout = svc.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const removal = removeEntry(layout, cellKey);
      if (!removal.changed) {
        return false;
      }
      if (svc.selectedBlockKey === cellKey) {
        svc.selectBlock(null);
      }
      svc.publishStructuralChange(located.outletName, removal.layout);
      return true;
    });
  }

  /**
   * Positions a block that just entered a grid (its foreign span already
   * discarded by the caller). The gesture is read from how it was dropped — a
   * "before" / "after" drop relative to a specific cell is a BESIDE cascade;
   * an "inside" / container-level drop is a GENERIC append — and the actual
   * placement is decided by `decideGridDrop`, the single rule chokepoint. The
   * decision is then applied to the layout.
   *
   * @param {Array<Object>} layout
   * @param {string} gridKey
   * @param {string} entryKeyValue - The just-inserted entry's key.
   * @param {string|null} targetKey - The cell the drop was relative to.
   * @param {"before"|"after"|"inside"} position
   * @returns {Array<Object>} The layout with the entry placed + dims synced.
   */
  positionEntering(layout, gridKey, entryKeyValue, targetKey, position) {
    const grid = findEntry(layout, gridKey);
    if (!grid) {
      return layout;
    }
    const decision = decideGridDrop({
      children: grid.children ?? [],
      declared: {
        columns: grid.args?.columns ?? DEFAULT_GRID_COLUMNS,
        rows: grid.args?.rows ?? DEFAULT_GRID_ROWS,
      },
      // The entry is already a child of the grid at this point, so it counts
      // as an in-grid source (its auto cell is credited as free).
      source: { kind: "existing", key: entryKeyValue },
      drop: this.#classifyGridDrop(gridKey, targetKey, position),
    });
    return this.#applyGridDecision(layout, gridKey, entryKeyValue, decision);
  }

  /**
   * Persists resized column widths as `columnFractions` (one ratio per
   * column). Written by the grid's column resize handles on pointerup; the
   * render normalizes the array to the live column count, so it can never
   * desync from `columns`. A deterministic resize, not a drop — no decider.
   *
   * @param {{gridKey: string, fractions: number[]}} args
   * @returns {boolean}
   */
  resizeColumns({ gridKey, fractions }) {
    const svc = this.service;
    const located = svc.layoutQuery.findEntryAndOutletSync(gridKey);
    if (!located) {
      return false;
    }
    return svc.recordStructural([located.outletName], () => {
      const layout = svc.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryInPlace(layout, gridKey, {
        ...located.entry,
        args: { ...located.entry.args, columnFractions: fractions },
      });
      if (!result.changed) {
        return false;
      }
      svc.publishStructuralChange(located.outletName, result.layout);
      return true;
    });
  }

  /**
   * Updates a grid cell's `column` / `row` placement. Written by the cell's
   * resize handle on pointerup. A deterministic resize of one cell against an
   * explicit rect, not a drop — no decider.
   *
   * Resize does NOT grow the grid: the handle already clamps the span to the
   * EFFECTIVE (rendered) dimensions, so the committed placement never reaches
   * past what's already visible. Declared `args.columns` / `args.rows` are left
   * untouched — growing the declared track count is reserved for drops. (The
   * effective size is recomputed from the children on every render via
   * `gridDimensions`, so a wider span still renders; it just doesn't bake a new
   * column / row into the author's declared grid.)
   *
   * @param {{slotKey: string, column: string, row: string}} args
   * @returns {boolean}
   */
  resizeSlot({ slotKey, column, row }) {
    const svc = this.service;
    const located = svc.layoutQuery.findEntryAndOutletSync(slotKey);
    if (!located || !svc.layoutQuery.isGridCellEntry(located.entry)) {
      return false;
    }
    // An empty merged cell shrunk to a single base cell dissolves rather than
    // persisting a degenerate 1×1 entry — the overlay re-derives that position
    // as a derived empty. (A filled span resized to 1×1 stays a real block.)
    if (isMergedCell(located.entry) && this.#isSingleCell(column, row)) {
      return this.splitCell({ cellKey: slotKey });
    }
    return svc.recordStructural([located.outletName], () => {
      const layout = svc.layoutQuery.readResolvedLayout(located.outletName);
      if (!layout) {
        return false;
      }
      const result = replaceEntryContainerArgs(
        layout,
        slotKey,
        "grid",
        (current) => ({ ...current, column, row })
      );
      if (!result.changed) {
        return false;
      }
      svc.publishStructuralChange(located.outletName, result.layout);
      return true;
    });
  }

  /**
   * Writes a grid's declared `args.columns` / `args.rows` up to match what its
   * children actually occupy (per core's `gridDimensions`), so the rendered
   * (effective) size never exceeds the declared size and no out-of-bounds
   * badge can arise from an editor operation. Only ever grows — a deliberate
   * dimension-field shrink below content is left alone so its warning still
   * surfaces. When columns grow, the stored `columnFractions` are renormalized
   * to the new count so the rendered track list can't desync.
   *
   * @param {Array<Object>} layout
   * @param {string} gridKey
   * @returns {Array<Object>}
   */
  syncDeclaredToUsage(layout, gridKey) {
    const grid = findEntry(layout, gridKey);
    if (!grid) {
      return layout;
    }
    const declared = {
      columns: grid.args?.columns ?? DEFAULT_GRID_COLUMNS,
      rows: grid.args?.rows ?? DEFAULT_GRID_ROWS,
    };
    const effective = gridDimensions(declared, grid.children);
    if (
      effective.columns === declared.columns &&
      effective.rows === declared.rows
    ) {
      return layout;
    }
    const nextArgs = {
      ...grid.args,
      columns: effective.columns,
      rows: effective.rows,
    };
    if (
      effective.columns !== declared.columns &&
      Array.isArray(grid.args?.columnFractions) &&
      grid.args.columnFractions.length > 0
    ) {
      nextArgs.columnFractions = normalizeFractions(
        grid.args.columnFractions,
        effective.columns
      );
    }
    const result = replaceEntryInPlace(layout, gridKey, {
      ...grid,
      args: nextArgs,
    });
    return result.changed ? result.layout : layout;
  }

  /**
   * Applies a `decideGridDrop` decision that places a single entry inside a
   * grid — the `fill` / `append` / `cascade` outcomes, where the entry is
   * already a child and only its placement (and any cascaded neighbours')
   * changes. Cascaded neighbours move first, then the source lands at the
   * decision's placement, then the grid's declared size is synced to usage.
   * `swap` / `replace` are two-entry trades handled separately, so they don't
   * pass through here.
   *
   * @param {Array<Object>} layout
   * @param {string} gridKey
   * @param {string} entryKeyValue - The entry being placed.
   * @param {import("discourse/plugins/discourse-wireframe/discourse/lib/grid-drop").GridDropDecision} decision
   * @returns {Array<Object>}
   */
  #applyGridDecision(layout, gridKey, entryKeyValue, decision) {
    let next = layout;
    for (const move of decision.moves) {
      const result = replaceEntryContainerArgs(
        next,
        move.slotKey,
        "grid",
        (current) => ({ ...current, column: move.column, row: move.row })
      );
      if (result.changed) {
        next = result.layout;
      }
    }
    if (decision.placement) {
      const placed = replaceEntryContainerArgs(
        next,
        entryKeyValue,
        "grid",
        (current) => ({
          align: "stretch",
          justify: "stretch",
          ...current,
          column: decision.placement.column,
          row: decision.placement.row,
        })
      );
      if (placed.changed) {
        next = placed.layout;
      }
    }
    return this.syncDeclaredToUsage(next, gridKey);
  }

  /**
   * Classifies an enter-style drop (`before` / `after` / `inside` a target)
   * into the normalized gesture `decideGridDrop` consumes. A before / after
   * drop beside a specific cell is BESIDE, anchored on that cell (so a
   * spanning anchor's full rect drives the cascade); everything else —
   * including a drop on the grid container itself — is GENERIC.
   *
   * @param {string} gridKey
   * @param {string|null} targetKey
   * @param {"before"|"after"|"inside"} position
   * @returns {{gesture: string, anchorKey?: string, direction?: string}}
   */
  #classifyGridDrop(gridKey, targetKey, position) {
    if (
      (position === "before" || position === "after") &&
      targetKey &&
      targetKey !== gridKey
    ) {
      return {
        gesture: GRID_DROP_GESTURES.BESIDE,
        anchorKey: targetKey,
        direction: position === "before" ? "left" : "right",
      };
    }
    return { gesture: GRID_DROP_GESTURES.GENERIC };
  }

  /**
   * Lands the dropped source at `placement`, handling all three source
   * shapes: a new palette block is minted and inserted; a same-grid cell is
   * re-placed in situ; a cell arriving from another grid / outlet is first
   * relocated into the target grid (foreign span discarded) and then placed.
   * Publishes each step; the caller syncs declared dimensions afterward.
   *
   * @param {string} outletName
   * @param {string} gridKey
   * @param {Object} source - The drop request's `source`.
   * @param {{entry: Object, outletName: string}|null} sourceLocated
   * @param {{column: string, row: string}} placement
   * @returns {boolean}
   */
  #landSourceAt(outletName, gridKey, source, sourceLocated, placement) {
    const svc = this.service;
    const { column, row } = placement;

    if (source.kind === "new") {
      const layout = svc.layoutQuery.readResolvedLayout(outletName);
      if (!layout) {
        return false;
      }
      const cellEntry = {
        block: source.blockName,
        args: { ...(source.defaultArgs ?? {}) },
        containerArgs: {
          grid: { column, row, align: "stretch", justify: "stretch" },
        },
      };
      const insertion = insertEntryAt(layout, gridKey, cellEntry, "inside");
      if (!insertion.changed) {
        return false;
      }
      svc.publishStructuralChange(outletName, insertion.layout);
      svc.selectInsertedEntry(cellEntry);
      return true;
    }

    // An existing cell already in this grid is just re-placed; one arriving
    // from elsewhere is relocated in first (without auto-positioning — the
    // exact landing cell is written right after).
    const sameGrid =
      sourceLocated.outletName === outletName &&
      svc.layoutQuery.isCellInGrid(sourceLocated.entry, gridKey);

    // Snapshot the source's prior rect + grid before it moves, so a multi-cell
    // region it leaves behind is preserved as a merged cell (the same shape a
    // delete preserves) rather than shattering into derived single cells.
    const priorPlacement = parsePlacement(sourceLocated.entry.containerArgs);
    const priorParent = svc.layoutQuery.findEntryParent(source.key);
    const priorGridKey = sameGrid
      ? gridKey
      : priorParent
        ? entryKey(priorParent)
        : null;
    const priorOutlet = sourceLocated.outletName;

    if (!sameGrid) {
      const moved = svc.moveAcrossOutlets({
        sourceOutletName: sourceLocated.outletName,
        targetOutletName: outletName,
        sourceKey: source.key,
        targetKey: gridKey,
        position: "inside",
        autoPosition: false,
      });
      if (!moved) {
        return false;
      }
    }
    const layout = svc.layoutQuery.readResolvedLayout(outletName);
    const result = replaceEntryContainerArgs(
      layout,
      source.key,
      "grid",
      (current) => ({ ...current, column, row })
    );
    if (result.changed) {
      svc.publishStructuralChange(outletName, result.layout);
    }
    if (priorGridKey) {
      this.#restoreVacatedSpan(priorOutlet, priorGridKey, priorPlacement);
    }
    return true;
  }

  /**
   * Preserves a multi-cell region a moved block vacated by minting an empty
   * merged cell at its old rect — so moving a spanning block out of a region
   * leaves that region as one held-open merged cell, matching what a delete
   * does, instead of letting it re-derive as separate single cells. A no-op
   * for single cells (those stay derived) and guarded by the shared `rectIsFree`
   * so a cascade that refilled the rect — or a move onto part of the rect — never
   * mints an overlapping or duplicate cell.
   *
   * @param {string} outletName - The outlet the prior grid lives in.
   * @param {string} gridKey - The grid the block was in before the move.
   * @param {{column: {start: number, end: number}, row: {start: number, end: number}}} priorPlacement
   * @returns {void}
   */
  #restoreVacatedSpan(outletName, gridKey, priorPlacement) {
    const svc = this.service;
    const { column, row } = priorPlacement;
    if (column.start == null || row.start == null) {
      return;
    }
    if (column.end - column.start <= 1 && row.end - row.start <= 1) {
      return;
    }
    const layout = svc.layoutQuery.readResolvedLayout(outletName);
    if (!layout) {
      return;
    }
    const grid = findEntry(layout, gridKey);
    if (!grid) {
      return;
    }
    if (!rectIsFree(grid.children ?? [], { column, row })) {
      return;
    }
    const cellEntry = {
      block: LAYOUT_MERGED_CELL_BLOCK,
      args: {},
      containerArgs: {
        grid: {
          column: formatTrack(column),
          row: formatTrack(row),
          align: "stretch",
          justify: "stretch",
        },
      },
    };
    const insertion = insertEntryAt(layout, gridKey, cellEntry, "inside");
    if (insertion.changed) {
      svc.publishStructuralChange(
        outletName,
        this.syncDeclaredToUsage(insertion.layout, gridKey)
      );
    }
  }

  /**
   * Executes a `fill` / `append` / `cascade` decision: apply the cascade
   * displacements (if any) so the landing sees post-shift occupancy, land
   * the source at the decision's placement, then grow the grid's declared
   * size to match usage.
   *
   * @param {string} outletName
   * @param {string} gridKey
   * @param {Object} source
   * @param {{entry: Object, outletName: string}|null} sourceLocated
   * @param {import("discourse/plugins/discourse-wireframe/discourse/lib/grid-drop").GridDropDecision} decision
   * @returns {boolean}
   */
  #place(outletName, gridKey, source, sourceLocated, decision) {
    const svc = this.service;
    for (const move of decision.moves) {
      const layout = svc.layoutQuery.readResolvedLayout(outletName);
      const result = replaceEntryContainerArgs(
        layout,
        move.slotKey,
        "grid",
        (current) => ({ ...current, column: move.column, row: move.row })
      );
      if (!result.changed) {
        return false;
      }
      svc.publishStructuralChange(outletName, result.layout);
    }
    if (
      !this.#landSourceAt(
        outletName,
        gridKey,
        source,
        sourceLocated,
        decision.placement
      )
    ) {
      return false;
    }
    svc.publishStructuralChange(
      outletName,
      this.syncDeclaredToUsage(
        svc.layoutQuery.readResolvedLayout(outletName),
        gridKey
      )
    );
    return true;
  }

  /**
   * Executes a `replace` decision (Shift-held drop onto an occupied cell):
   * remove the occupant, then land the source at the freed cell.
   *
   * @param {string} outletName
   * @param {string} gridKey
   * @param {Object} source
   * @param {{entry: Object, outletName: string}|null} sourceLocated
   * @param {import("discourse/plugins/discourse-wireframe/discourse/lib/grid-drop").GridDropDecision} decision
   * @returns {boolean}
   */
  #replace(outletName, gridKey, source, sourceLocated, decision) {
    const svc = this.service;
    const layout = svc.layoutQuery.readResolvedLayout(outletName);
    const removal = removeEntry(layout, decision.swapWith);
    if (!removal.changed) {
      return false;
    }
    svc.publishStructuralChange(outletName, removal.layout);
    if (
      !this.#landSourceAt(
        outletName,
        gridKey,
        source,
        sourceLocated,
        decision.placement
      )
    ) {
      return false;
    }
    svc.publishStructuralChange(
      outletName,
      this.syncDeclaredToUsage(
        svc.layoutQuery.readResolvedLayout(outletName),
        gridKey
      )
    );
    return true;
  }

  /**
   * Executes a `swap` decision: the source trades places with the cell's
   * occupant. Within one grid the two cells trade `column` / `row`; across
   * two grids each block moves into the other's grid and takes its cell, so
   * the drop never overlaps. Only grid-cell sources can swap — a source from
   * a non-grid container has no cell to give up, so it no-ops.
   *
   * @param {string} outletName
   * @param {Object} source
   * @param {{entry: Object, outletName: string}|null} sourceLocated
   * @param {import("discourse/plugins/discourse-wireframe/discourse/lib/grid-drop").GridDropDecision} decision
   * @returns {boolean}
   */
  #swap(outletName, source, sourceLocated, decision) {
    const svc = this.service;
    const occupant = svc.layoutQuery.findEntryAndOutletSync(decision.swapWith);
    if (
      !sourceLocated ||
      !occupant ||
      occupant.outletName !== outletName ||
      !svc.layoutQuery.isGridCellEntry(sourceLocated.entry) ||
      !svc.layoutQuery.isGridCellEntry(occupant.entry)
    ) {
      return false;
    }
    const sourcePlacement = {
      column: sourceLocated.entry.containerArgs?.grid?.column ?? "auto",
      row: sourceLocated.entry.containerArgs?.grid?.row ?? "auto",
    };
    const occupantPlacement = {
      column: occupant.entry.containerArgs?.grid?.column ?? "auto",
      row: occupant.entry.containerArgs?.grid?.row ?? "auto",
    };
    const layout0 = svc.layoutQuery.readResolvedLayout(outletName);
    const sourceParent = svc.layoutQuery.findEntryParent(source.key);
    const occupantParent = svc.layoutQuery.findEntryParent(decision.swapWith);
    const sourceParentKey = sourceParent ? entryKey(sourceParent) : null;
    const occupantParentKey = occupantParent ? entryKey(occupantParent) : null;

    // Cross-grid trade: relocate each block into the other's grid at the
    // other's cell.
    if (
      sourceParentKey &&
      occupantParentKey &&
      sourceParentKey !== occupantParentKey
    ) {
      const removalSource = removeEntry(layout0, source.key);
      if (!removalSource.changed || !removalSource.removed) {
        return false;
      }
      const removalOccupant = removeEntry(
        removalSource.layout,
        decision.swapWith
      );
      if (!removalOccupant.changed || !removalOccupant.removed) {
        return false;
      }
      const insSource = insertEntryAt(
        removalOccupant.layout,
        occupantParentKey,
        this.#withGridPlacement(removalSource.removed, occupantPlacement),
        "inside"
      );
      if (!insSource.changed) {
        return false;
      }
      const insOccupant = insertEntryAt(
        insSource.layout,
        sourceParentKey,
        this.#withGridPlacement(removalOccupant.removed, sourcePlacement),
        "inside"
      );
      if (!insOccupant.changed) {
        return false;
      }
      svc.publishStructuralChange(outletName, insOccupant.layout);
      return true;
    }

    // Same-grid placement swap.
    const first = replaceEntryContainerArgs(
      layout0,
      source.key,
      "grid",
      (current) => ({
        ...current,
        column: occupantPlacement.column,
        row: occupantPlacement.row,
      })
    );
    if (!first.changed) {
      return false;
    }
    const second = replaceEntryContainerArgs(
      first.layout,
      decision.swapWith,
      "grid",
      (current) => ({
        ...current,
        column: sourcePlacement.column,
        row: sourcePlacement.row,
      })
    );
    if (!second.changed) {
      return false;
    }
    svc.publishStructuralChange(outletName, second.layout);
    return true;
  }

  /**
   * Returns a copy of `entry` with its `containerArgs.grid` column / row
   * overwritten (other grid props like align / justify preserved). Used to
   * re-place a detached entry during a cross-grid trade.
   *
   * @param {Object} entry
   * @param {{column: string, row: string}} placement
   * @returns {Object}
   */
  #withGridPlacement(entry, { column, row }) {
    return {
      ...entry,
      containerArgs: {
        ...(entry.containerArgs ?? {}),
        grid: {
          align: "stretch",
          justify: "stretch",
          ...(entry.containerArgs?.grid ?? {}),
          column,
          row,
        },
      },
    };
  }

  /**
   * Whether a `column` / `row` shorthand pair resolves to a single 1×1 base
   * cell (each axis spans exactly one track). Used to detect a merged cell
   * resized down to a single cell, which should dissolve rather than persist.
   *
   * @param {string} column
   * @param {string} row
   * @returns {boolean}
   */
  #isSingleCell(column, row) {
    const placement = parsePlacement({ grid: { column, row } });
    if (
      placement.column.start == null ||
      placement.column.end == null ||
      placement.row.start == null ||
      placement.row.end == null
    ) {
      return false;
    }
    return (
      placement.column.end - placement.column.start === 1 &&
      placement.row.end - placement.row.start === 1
    );
  }
}
