// @ts-check
import {
  DEFAULT_GRID_COLUMNS,
  DEFAULT_GRID_ROWS,
  gridDimensions,
  normalizeFractions,
} from "discourse/blocks";
import {
  decideGridDrop,
  GRID_DROP_GESTURES,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-drop";
import {
  findEntry,
  replaceEntryContainerArgs,
  replaceEntryInPlace,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";

/**
 * Pure grid-placement computation shared by the grid manipulator (drop / resize
 * orchestration) and the block-mutation move paths. Every function here is a
 * dependency-free layout transform — it takes the resolved `layout` plus keys
 * and returns a new layout (or a normalized gesture / decision), never touching
 * any service. Keeping it standalone lets both consumers import it directly
 * without an instance reference, so the grid and block-mutation concerns don't
 * have to depend on each other.
 */

/**
 * Re-places an entry that's already a child of `gridKey` according to the
 * `decideGridDrop` rule chokepoint — the `fill` / `append` / `cascade` outcomes
 * of an enter-style drop. Returns the layout unchanged when the grid is gone.
 *
 * @param {Array<Object>} layout
 * @param {string} gridKey
 * @param {string} entryKeyValue - The entry being (re)placed; counts as an
 *   in-grid source so its current cell is credited as free.
 * @param {string|null} targetKey - The cell the drop landed before/after, or
 *   the grid itself.
 * @param {"before"|"after"|"inside"} position
 * @returns {Array<Object>}
 */
export function positionEntering(
  layout,
  gridKey,
  entryKeyValue,
  targetKey,
  position
) {
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
    drop: classifyGridDrop(gridKey, targetKey, position),
  });
  return applyGridDecision(layout, gridKey, entryKeyValue, decision);
}

/**
 * Writes a grid's declared `args.columns` / `args.rows` up to match what its
 * children actually occupy (per core's `gridDimensions`), so the rendered
 * (effective) size never exceeds the declared size and no out-of-bounds badge
 * can arise from an editor operation. Only ever grows — a deliberate
 * dimension-field shrink below content is left alone so its warning still
 * surfaces. When columns grow, the stored `columnFractions` are renormalized to
 * the new count so the rendered track list can't desync.
 *
 * @param {Array<Object>} layout
 * @param {string} gridKey
 * @returns {Array<Object>}
 */
export function syncDeclaredToUsage(layout, gridKey) {
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
 * Classifies an enter-style drop (`before` / `after` / `inside` a target) into
 * the normalized gesture `decideGridDrop` consumes. A before / after drop beside
 * a specific cell is BESIDE, anchored on that cell (so a spanning anchor's full
 * rect drives the cascade); everything else — including a drop on the grid
 * container itself — is GENERIC.
 *
 * @param {string} gridKey
 * @param {string|null} targetKey
 * @param {"before"|"after"|"inside"} position
 * @returns {{gesture: string, anchorKey?: string, direction?: string}}
 */
function classifyGridDrop(gridKey, targetKey, position) {
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
 * Applies a `decideGridDrop` decision that places a single entry inside a grid —
 * the `fill` / `append` / `cascade` outcomes, where the entry is already a child
 * and only its placement (and any cascaded neighbours') changes. Cascaded
 * neighbours move first, then the source lands at the decision's placement, then
 * the grid's declared size is synced to usage. `swap` / `replace` are two-entry
 * trades handled separately, so they don't pass through here.
 *
 * @param {Array<Object>} layout
 * @param {string} gridKey
 * @param {string} entryKeyValue - The entry being placed.
 * @param {import("discourse/plugins/discourse-wireframe/discourse/lib/grid-drop").GridDropDecision} decision
 * @returns {Array<Object>}
 */
function applyGridDecision(layout, gridKey, entryKeyValue, decision) {
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
  return syncDeclaredToUsage(next, gridKey);
}
