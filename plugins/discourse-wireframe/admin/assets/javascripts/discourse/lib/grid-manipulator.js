// @ts-check
import { gridDimensions, normalizeFractions } from "discourse/blocks";
import {
  decideGridDrop,
  GRID_DROP_GESTURES,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-drop";
import {
  findEntry,
  replaceEntryContainerArgs,
  replaceEntryInPlace,
} from "./mutate-layout";

/**
 * Owns every mutation of a grid `wf:layout` so the grid drop rules can't be
 * bypassed. Drops are described, not chosen: callers hand a request to a
 * single entry point that routes it through `decideGridDrop` (the rule
 * chokepoint) and into private executors. Non-drop manipulations (resizing a
 * cell or the column tracks, applying a template) also live here, but those
 * are deterministic and do not consult the decider.
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
        columns: grid.args?.columns ?? 3,
        rows: grid.args?.rows ?? 2,
      },
      // The entry is already a child of the grid at this point, so it counts
      // as an in-grid source (its auto cell is credited as free).
      source: { kind: "existing", key: entryKeyValue },
      drop: this.#classifyGridDrop(gridKey, targetKey, position),
    });
    return this.#applyGridDecision(layout, gridKey, entryKeyValue, decision);
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
      columns: grid.args?.columns ?? 3,
      rows: grid.args?.rows ?? 2,
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
}
