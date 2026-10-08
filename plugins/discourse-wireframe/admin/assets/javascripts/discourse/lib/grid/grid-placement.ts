import {
  DEFAULT_GRID_COLUMNS,
  DEFAULT_GRID_ROWS,
  gridDimensions,
  normalizeFractions,
} from "discourse/blocks";
import type { LayoutEntry } from "discourse/blocks/types";
import {
  decideGridDrop,
  GRID_DROP_GESTURES,
  type GridDropDecision,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-drop";
import {
  findEntry,
  replaceEntryContainerArgs,
  replaceEntryInPlace,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";

/** The axis-directed sense of an enter-style BESIDE drop. */
type GridDropDirection = "left" | "right" | "up" | "down";

/** The relative position of an enter-style drop against its target. */
type EnterPosition = "before" | "after" | "inside";

/**
 * The normalized gesture a `classifyGridDrop` call resolves an enter-style
 * drop into, ready for `decideGridDrop` to consume.
 */
type ClassifiedGridDrop =
  | {
      /** Generic drop without a neighbouring cell. */
      gesture: typeof GRID_DROP_GESTURES.GENERIC;
    }
  | {
      /** Drop beside an existing cell. */
      gesture: typeof GRID_DROP_GESTURES.BESIDE;
      /** Existing cell anchoring the beside gesture. */
      anchorKey: string;
      /** Axis-directed cascade direction. */
      direction: GridDropDirection;
    };

type GridLayoutArgs = {
  /** Declared number of grid columns. */
  columns?: number;
  /** Declared number of grid rows. */
  rows?: number;
  /** Relative width assigned to each grid column. */
  columnFractions?: number[];
};

/**
 * Reads the grid-specific argument bag from a layout entry.
 *
 * @param entry - Grid layout entry whose arguments should be read.
 * @returns The grid-specific argument view.
 */
function gridLayoutArgs(entry: LayoutEntry): GridLayoutArgs {
  // TODO(devxp-typescript-pending): remove this cast once core can refine a
  // `LayoutEntry`'s generic args from the resolved block schema.
  return (entry.args ?? {}) as GridLayoutArgs;
}

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
 * @param layout - Layout containing the grid and entry.
 * @param gridKey - Stable key of the destination grid.
 * @param entryKeyValue - The entry being (re)placed; counts as an in-grid
 *   source so its current cell is credited as free.
 * @param targetKey - The cell the drop landed before/after, or the grid itself.
 * @param position - Relative drop position against the target.
 * @returns The updated layout, or the original layout when no change applies.
 */
export function positionEntering(
  layout: LayoutEntry[],
  gridKey: string,
  entryKeyValue: string,
  targetKey: string | null,
  position: EnterPosition
): LayoutEntry[] {
  const grid = findEntry(layout, gridKey);
  if (!grid) {
    return layout;
  }
  const args = gridLayoutArgs(grid);
  const decision = decideGridDrop({
    children: grid.children ?? [],
    declared: {
      columns: args.columns ?? DEFAULT_GRID_COLUMNS,
      rows: args.rows ?? DEFAULT_GRID_ROWS,
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
 * @param layout - Layout containing the grid to synchronize.
 * @param gridKey - Stable key of the grid to synchronize.
 * @returns The synchronized layout, or the original layout when already valid.
 */
export function syncDeclaredToUsage(
  layout: LayoutEntry[],
  gridKey: string
): LayoutEntry[] {
  const grid = findEntry(layout, gridKey);
  if (!grid) {
    return layout;
  }
  const args = gridLayoutArgs(grid);
  const declared = {
    columns: args.columns ?? DEFAULT_GRID_COLUMNS,
    rows: args.rows ?? DEFAULT_GRID_ROWS,
  };
  const effective = gridDimensions(declared, grid.children);
  if (
    effective.columns === declared.columns &&
    effective.rows === declared.rows
  ) {
    return layout;
  }
  const nextArgs: GridLayoutArgs & Record<string, unknown> = {
    ...grid.args,
    columns: effective.columns,
    rows: effective.rows,
  };
  if (
    effective.columns !== declared.columns &&
    Array.isArray(args.columnFractions) &&
    args.columnFractions.length > 0
  ) {
    nextArgs.columnFractions = normalizeFractions(
      args.columnFractions,
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
 * @param gridKey - Stable key of the destination grid.
 * @param targetKey - Stable key of the target entry, or the grid itself.
 * @param position - Relative position reported by the enter-style drop.
 * @returns The normalized grid-drop gesture.
 */
function classifyGridDrop(
  gridKey: string,
  targetKey: string | null,
  position: EnterPosition
): ClassifiedGridDrop {
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
 * @param layout - Layout containing the grid and entry.
 * @param gridKey - Stable key of the destination grid.
 * @param entryKeyValue - The entry being placed.
 * @param decision - Pure placement decision to apply.
 * @returns The updated and dimension-synchronized layout.
 */
function applyGridDecision(
  layout: LayoutEntry[],
  gridKey: string,
  entryKeyValue: string,
  decision: GridDropDecision
): LayoutEntry[] {
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
    const placement = decision.placement;
    const placed = replaceEntryContainerArgs(
      next,
      entryKeyValue,
      "grid",
      (current) => ({
        align: "stretch",
        justify: "stretch",
        ...current,
        column: placement.column,
        row: placement.row,
      })
    );
    if (placed.changed) {
      next = placed.layout;
    }
  }
  return syncDeclaredToUsage(next, gridKey);
}
