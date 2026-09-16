import { gridDimensions, parsePlacement } from "discourse/blocks";
import { entryKey } from "./entry-key";
import {
  computeShiftPlan,
  type GridEntry,
  isMergedCell,
  nextFreeCellInReadingOrder,
  type ShiftPlanArgs,
} from "./grid-math";

/**
 * The single rule chokepoint for dropping a block into a grid layout.
 *
 * Every drop into a grid — from the palette, from the same grid, from
 * another grid, or from a non-grid container — is classified by the caller
 * into one of three gestures, and each gesture has exactly one validated
 * outcome. `decideGridDrop` takes the grid's current state plus the
 * classified drop and returns the decision — WHAT action to take and the
 * resulting placement(s) — without touching the layout, the service, or
 * any outlet. Callers (the overlay's drop dispatch and the service's
 * placement methods) execute the returned decision; this module owns the
 * rules so they live in exactly one place and are exhaustively testable.
 *
 * Notation in the examples: `[A]` a filled cell, `[_]` an empty cell (a
 * hole), `^` the drop point, `X` the dropped block; "grow" means a real
 * track is added (declared `columns` or `rows` increases).
 *
 * A block ENTERING a grid always has any foreign span discarded — it lands
 * 1×1, then the gesture below positions it. A same-grid source's current
 * cell is credited as free during planning, so a cascade can rotate into
 * the space it vacates.
 *
 * ---
 *
 * R1 — INTO a cell (gesture `INTO`). Hard rule: fill or swap, NEVER shift
 * other cells, NEVER grow to make room.
 *
 *  - Empty cell → FILL it, 1×1.
 *      `[A][_][B]` drop X into the hole → `[A][X][B]` (columns unchanged).
 *  - Occupied cell, existing source → SWAP (non-destructive trade). The
 *    source takes the occupant's cell; the occupant takes the source's old
 *    cell. Same grid trades placements; across grids the two blocks trade
 *    grids (the executor handles the two-grid case).
 *      `[A][B]` drop A onto B → `[B][A]`.
 *  - Occupied cell, existing source, Shift held → REPLACE: the source
 *    takes the cell and the occupant is removed.
 *  - Occupied cell, NEW (palette) source → NOOP: a freshly minted block has
 *    no cell to trade away, so it cannot swap onto an occupant.
 *  - The only growth on an INTO drop is a precise drop into a cell beyond
 *    the current rows (e.g. an explicit cell in a brand-new row), which
 *    extends declared usage (R5) — it is not growth to make room.
 *
 * R2 — BESIDE a cell (gesture `BESIDE`, with a `direction`). Axis-pure
 * cascade insert: insert at the drop slot, then ripple existing cells
 * along the gesture's axis only (horizontal for left/right, vertical for
 * up/down).
 *
 *  - The cascade is absorbed by the first hole a displaced cell is pushed
 *    into; nothing past that hole moves.
 *      `[A][B][_][C]` drop X before B → `[A][X][B][C]` (B lands on the
 *      hole at 3; columns unchanged).
 *  - If the cascade reaches the far edge with no absorbing hole, GROW that
 *    axis by one and land there.
 *      `[A][B][C]` drop X before B → `[A][X][B][C]` (columns 3 → 4).
 *  - A hole AT the drop point is treated as content and shifts along (it
 *    does NOT absorb the drop), so dropping before a hole preserves it and
 *    can still grow.
 *      `[A][_][B]` drop X before the hole → `[A][X][_][B]` (columns 3 → 4).
 *  - A LATER hole can still absorb the cascade.
 *      `[A][_][B][_]` drop X before the first hole → `[A][X][_][B]`
 *      (B lands on the trailing hole; columns unchanged).
 *  - Multi-row is axis-pure: a row-1 horizontal cascade ignores row-2 holes
 *    and grows a column.
 *      Row1 `[A][B][C]` (full), Row2 `[D][_][_]`; drop X before B in row 1
 *      → Row1 `[A][X][B][C]` (columns 3 → 4), Row2 unchanged.
 *  - When no cascade plan fits (e.g. the anchor cell has no explicit
 *    placement), the decision falls back to APPEND (R3).
 *
 * R3 — GENERIC drop (gesture `GENERIC`). Append at the next free cell in
 * reading order (row-major); when the grid is full, add a row and place in
 * its first cell. This is the only path that uses "next free slot".
 *      Row1 `[A][B][C]` Row2 `[D][E][F]` (full), generic drop of X
 *      → Row3 `[X][_][_]` (rows + 1).
 *
 * R5 — Declared dimensions track usage. Whenever a gesture grows the grid,
 * the returned `declared` is bumped so the rendered (effective) size never
 * exceeds declared. It only ever grows — a hand-authored shrink below
 * content is left alone — so an in-editor drop can never produce an
 * out-of-bounds cell.
 *
 * Source-side invariants (R4) — a move always removes the source and never
 * reshapes the SOURCE grid — are the executor's responsibility, not this
 * decision; the decision only describes what happens in the target grid.
 */

/** A grid cell coordinate, 1-indexed to match CSS Grid line numbering. */
type GridCell = {
  /** One-based grid column. */
  column: number;
  /** One-based grid row. */
  row: number;
};

/** A rectangular grid region, in CSS Grid line numbers with exclusive ends. */
type CellRect = {
  /** Resolved column lines. */
  column: {
    /** Inclusive starting column line. */
    start: number;
    /** Exclusive ending column line. */
    end: number;
  };
  /** Resolved row lines. */
  row: {
    /** Inclusive starting row line. */
    start: number;
    /** Exclusive ending row line. */
    end: number;
  };
};

/** The declared / effective size of a grid. */
type GridDimensions = {
  /** Grid column count. */
  columns: number;
  /** Grid row count. */
  rows: number;
};

/** A CSS Grid line shorthand pair (e.g. `"2"`, `"1 / 4"`, `"auto"`). */
type GridPlacementRef = {
  /** CSS Grid column-line shorthand. */
  column: string;
  /** CSS Grid row-line shorthand. */
  row: string;
};

/** What is being dropped: a fresh palette block, or an existing entry. */
type GridDropSource = {
  /** Whether the source is new or already in a layout. */
  kind: "new" | "existing";
  /** Stable key for an existing source. */
  key: string | null;
};

/** The cascade axis a `BESIDE` drop runs along. */
type GridDropDirection = "left" | "right" | "up" | "down";

/** The classified drop gesture and its gesture-specific geometry. */
type GridDrop =
  | {
      /** Drop onto a specific grid cell. */
      gesture: typeof GRID_DROP_GESTURES.INTO;
      /** Cell under the pointer. */
      cell: GridCell;
      /** Whether an occupied cell should be replaced. */
      shift?: boolean;
    }
  | {
      /** Drop beside a neighbouring grid cell. */
      gesture: typeof GRID_DROP_GESTURES.BESIDE;
      /** Cell adjacent to the pointer edge, when geometry resolved one. */
      cell?: GridCell | null;
      /** Stable key of the neighbouring anchor. */
      anchorKey: string | null;
      /** Cascade direction for the beside gesture. */
      direction: GridDropDirection;
    }
  | {
      /** Drop into the grid without a specific neighbour. */
      gesture: typeof GRID_DROP_GESTURES.GENERIC;
    };

/** The full input to {@link decideGridDrop}. */
export interface GridDropInput {
  /** Current target-grid entries. */
  children: GridEntry[];
  /** Persisted target-grid dimensions. */
  declared: GridDimensions;
  /** Block or palette item being dropped. */
  source: GridDropSource;
  /** Classified gesture and target geometry. */
  drop: GridDrop;
}

/** A displacement applied to an existing cell during a cascade. */
type GridDropMove = {
  /** Stable key of the displaced entry. */
  slotKey: string;
  /** Replacement column-line shorthand. */
  column: string;
  /** Replacement row-line shorthand. */
  row: string;
};

/**
 * The decision `decideGridDrop` returns for a single drop.
 *
 *  - `placement` — where the source lands, as CSS Grid line shorthand;
 *    `null` for `noop`.
 *  - `moves` — displacements applied to existing cells (only for `cascade`).
 *  - `swapWith` — the occupant's entry key, for `swap` and `replace`;
 *    `null` otherwise.
 *  - `declared` — the grid's declared dimensions after the drop; only ever
 *    grows (never shrinks), so the rendered grid never exceeds its declared
 *    size.
 */
export interface GridDropDecision {
  /** Operation the executor should perform. */
  action: GridDropAction;
  /** Placement assigned to the source. */
  placement: GridPlacementRef | null;
  /** Existing entries displaced by a cascade. */
  moves: GridDropMove[];
  /** Existing entry exchanged with or removed by the source. */
  swapWith: string | null;
  /** Persisted grid dimensions after the drop. */
  declared: GridDimensions;
}

/**
 * The closed set of drop gestures. The caller classifies the drop into one
 * of these from its own geometry (cursor zone, outline position) before
 * asking for a decision.
 */
export const GRID_DROP_GESTURES = {
  /** Onto a cell's interior — fill it or swap with its occupant. */
  INTO: "into",
  /** Against a cell's edge — cascade the row/column along one axis. */
  BESIDE: "beside",
  /** Onto the grid with no specific neighbour — append at the next free cell. */
  GENERIC: "generic",
} as const;

/** One of the {@link GRID_DROP_GESTURES} values. */
export type GridDropGesture =
  (typeof GRID_DROP_GESTURES)[keyof typeof GRID_DROP_GESTURES];

/**
 * The closed set of outcomes `decideGridDrop` can return. The action names
 * the operation; the rest of the decision carries its parameters.
 */
export const GRID_DROP_ACTIONS = {
  /** Place the source in an empty cell, 1×1. */
  FILL: "fill",
  /** Trade placements with the cell's occupant (non-destructive). */
  SWAP: "swap",
  /** Take the occupied cell; the occupant is removed (Shift-held drop). */
  REPLACE: "replace",
  /** Insert beside a cell, cascading existing cells to make room. */
  CASCADE: "cascade",
  /** Append at the next free cell (or a new row when full). */
  APPEND: "append",
  /** Nothing to do — the gesture is not valid for this source. */
  NOOP: "noop",
} as const;

/** One of the {@link GRID_DROP_ACTIONS} values. */
export type GridDropAction =
  (typeof GRID_DROP_ACTIONS)[keyof typeof GRID_DROP_ACTIONS];

/** The context every gesture decider shares, derived once per drop. */
type DecideContext = {
  /** Target children after excluding an in-grid source. */
  kids: GridEntry[];
  /** Persisted target dimensions before the drop. */
  declared: GridDimensions;
  /** Effective dimensions used for placement. */
  dims: GridDimensions;
  /** Block or palette item being dropped. */
  source: GridDropSource;
  /** Stable key of an existing source. */
  sourceKey: string | null;
  /** Whether the source already belongs to this grid. */
  inGrid: boolean;
};

/**
 * Decides the action and resulting placement for a single drop into a
 * grid. Pure — no DOM, no service, no mutation. Encodes the full rule set
 * documented at the top of this module.
 *
 * The source's foreign span (if any) is always discarded: it lands as a
 * single cell. A same-grid source's current cell is credited as free
 * during planning (so a cascade can rotate into the space it vacates).
 *
 * The returned decision per action:
 *
 *  - `FILL` / `APPEND` → `placement` is the landing cell; `moves` empty;
 *    `swapWith` null. `APPEND` may land in a new row (declared rows grow).
 *  - `CASCADE` → `placement` is the source's landing cell, `moves` lists
 *    the displaced cells' new placements; `declared` reflects any growth.
 *  - `SWAP` / `REPLACE` → `placement` is the occupant's (old) cell — where
 *    the source lands — and `swapWith` is the occupant's key; `declared`
 *    is unchanged (an INTO drop never grows to make room).
 *  - `NOOP` → `placement` null, nothing to do (palette block onto an
 *    occupied cell).
 *
 * `children` are the target grid's current child entries; `declared` its
 * `args.columns` / `args.rows`; `source` identifies what is being dropped
 * (`new` = freshly minted from the palette, `existing` = a block already
 * in the layout); `drop` is the classified gesture. A `BESIDE` drop anchors
 * on either a `cell` coordinate or an `anchorKey` (an existing child whose
 * full rect — including any span — anchors the cascade).
 *
 * @param input - Target-grid state and classified drop to decide.
 * @returns The validated operation and resulting placements.
 */
export function decideGridDrop({
  children,
  declared,
  source,
  drop,
}: GridDropInput): GridDropDecision {
  const kids = children ?? [];
  // Effective size: the larger of declared and what the children occupy,
  // so the decision always reasons about the grid as rendered.
  const dims = gridDimensions(declared, kids);
  const sourceKey = source?.key ?? null;
  const inGrid =
    sourceKey != null && kids.some((child) => entryKey(child) === sourceKey);
  const ctx: DecideContext = {
    kids,
    declared,
    dims,
    source,
    sourceKey,
    inGrid,
  };

  if (drop.gesture === GRID_DROP_GESTURES.INTO) {
    return decideInto(ctx, drop.cell, drop.shift);
  }

  if (drop.gesture === GRID_DROP_GESTURES.BESIDE) {
    const cascade = decideBeside(
      ctx,
      drop.cell,
      drop.anchorKey,
      drop.direction
    );
    if (cascade) {
      return cascade;
    }
    // No cascade plan fits (e.g. the anchor cell has no explicit
    // placement) — fall back to appending at the next free cell.
  }

  return decideGeneric(ctx);
}

/**
 * INTO a cell: fill it when empty, swap / replace its occupant when
 * filled. Never shifts other cells; the only growth is a precise drop
 * into a cell beyond the current rows (declared tracks usage, R5).
 *
 * @param context - State shared by all gesture deciders.
 * @param cell - Target cell for the drop.
 * @param shift - Whether the occupant should be replaced instead of swapped.
 * @returns The fill, swap, replace, or no-op decision.
 */
function decideInto(
  { kids, declared, source, sourceKey, inGrid }: DecideContext,
  cell: GridCell,
  shift?: boolean
): GridDropDecision {
  // A same-grid source sitting in the target cell isn't its own occupant.
  const occupant = slotCoveringCell(kids, cell, inGrid ? sourceKey : null);

  // An empty merged cell is consumed by the drop: the source lands at the
  // merged cell's full (possibly spanning) rect and the placeholder entry is
  // removed (REPLACE). This is the same consume-and-inherit outcome the direct
  // cell-fill path produces, so the overlay agrees with it — a drop onto a
  // merged cell never swaps or shifts, whatever the source or `shift` flag.
  if (occupant && isMergedCell(occupant)) {
    return {
      action: GRID_DROP_ACTIONS.REPLACE,
      placement: placementOf(occupant),
      moves: [],
      swapWith: entryKey(occupant),
      declared: { columns: declared.columns, rows: declared.rows },
    };
  }

  if (!occupant) {
    const placement = { column: `${cell.column}`, row: `${cell.row}` };
    return {
      action: GRID_DROP_ACTIONS.FILL,
      placement,
      moves: [],
      swapWith: null,
      declared: declaredFromRects(
        declared,
        finalRects(kids, sourceKey, inGrid, [], placement)
      ),
    };
  }

  // A freshly minted palette block has no cell to trade away, so it can't
  // swap onto an occupant — the gesture is a no-op for it.
  if (source.kind === "new") {
    return noop(declared);
  }

  return {
    action: shift ? GRID_DROP_ACTIONS.REPLACE : GRID_DROP_ACTIONS.SWAP,
    // The source takes the occupant's cell; the occupant takes the
    // source's old cell (swap) or is removed (replace) by the executor.
    placement: placementOf(occupant),
    moves: [],
    swapWith: entryKey(occupant),
    // Into a cell never grows the grid (hard rule, R1).
    declared: { columns: declared.columns, rows: declared.rows },
  };
}

/**
 * BESIDE a cell: axis-pure cascade. The cascade anchors on `anchorKey`'s
 * full rect when given (preserving a spanning anchor), otherwise on the
 * `cell` coordinate. Returns `null` when no cascade plan fits, so the
 * caller can fall back to a generic append.
 *
 * @param context - State shared by all gesture deciders.
 * @param cell - Target cell when no anchor entry is available.
 * @param anchorKey - Stable key of the entry anchoring the cascade.
 * @param direction - Axis-directed cascade direction.
 * @returns The cascade decision, or `null` when no plan fits.
 */
function decideBeside(
  { kids, declared, dims, sourceKey, inGrid }: DecideContext,
  cell: GridCell | null | undefined,
  anchorKey: string | null,
  direction: GridDropDirection
): GridDropDecision | null {
  const planArgs: ShiftPlanArgs = {
    slots: kids,
    sourceKey: inGrid ? sourceKey : null,
    dropSlotKey: anchorKey ?? null,
    dropCell: cell ?? null,
    direction,
    gridDims: dims,
    // A cascade that fills the line grows that axis rather than refusing.
    allowGrow: true,
  };
  const plan = computeShiftPlan(planArgs);
  if (!plan) {
    return null;
  }
  return {
    action: GRID_DROP_ACTIONS.CASCADE,
    placement: plan.sourceLanding,
    moves: plan.moves,
    swapWith: null,
    declared: declaredFromRects(
      declared,
      finalRects(kids, sourceKey, inGrid, plan.moves, plan.sourceLanding)
    ),
  };
}

/**
 * GENERIC drop: append at the next free cell in reading order, or the
 * first cell of a new row when the grid is full.
 *
 * @param context - State shared by all gesture deciders.
 * @returns The append decision.
 */
function decideGeneric({
  kids,
  declared,
  dims,
  sourceKey,
  inGrid,
}: DecideContext): GridDropDecision {
  // A same-grid source doesn't occupy its own target while we look for the
  // next free cell.
  const siblings = inGrid
    ? kids.filter((child) => entryKey(child) !== sourceKey)
    : kids;
  const free = nextFreeCellInReadingOrder(siblings, dims) ?? {
    column: 1,
    row: dims.rows + 1,
  };
  const placement = { column: `${free.column}`, row: `${free.row}` };
  return {
    action: GRID_DROP_ACTIONS.APPEND,
    placement,
    moves: [],
    swapWith: null,
    declared: declaredFromRects(
      declared,
      finalRects(kids, sourceKey, inGrid, [], placement)
    ),
  };
}

/**
 * The child entry whose placement covers `cell`, or `null` when the cell
 * is empty. Auto-placed children (no explicit column / row) never count as
 * covering a cell. `excludeKey` skips the source's own cell.
 *
 * @param kids - Grid children to search.
 * @param cell - Cell whose occupant should be located.
 * @param excludeKey - Stable key whose placement should be ignored.
 * @returns The covering entry, or `null` when the cell is free.
 */
function slotCoveringCell(
  kids: GridEntry[],
  cell: GridCell,
  excludeKey: string | null
): GridEntry | null {
  // A single cell is a 1×1 rect (end lines are exclusive).
  const rect: CellRect = {
    column: { start: cell.column, end: cell.column + 1 },
    row: { start: cell.row, end: cell.row + 1 },
  };
  for (const child of kids) {
    if (excludeKey && entryKey(child) === excludeKey) {
      continue;
    }
    if (entryCoversRect(child, rect)) {
      return child;
    }
  }
  return null;
}

/**
 * Whether an explicitly placed child's rect intersects `rect`. Auto-placed
 * children (no pinned column / row) never count as covering anything.
 * Both rects use CSS Grid line numbers with exclusive end lines, so two
 * rects overlap when each axis's intervals overlap.
 *
 * @param child - Grid entry whose placement should be checked.
 * @param rect - Grid region to test for overlap.
 * @returns Whether the entry explicitly overlaps the region.
 */
function entryCoversRect(child: GridEntry, rect: CellRect): boolean {
  const placement = parsePlacement(child.containerArgs);
  if (placement.column.start == null || placement.row.start == null) {
    return false;
  }
  return (
    placement.column.start < rect.column.end &&
    rect.column.start < placement.column.end &&
    placement.row.start < rect.row.end &&
    rect.row.start < placement.row.end
  );
}

/**
 * Whether the rectangular grid region `rect` is unoccupied by any explicitly
 * placed child. The single occupancy primitive shared by the drop decider
 * (via `slotCoveringCell`) and the direct spanning insert (`mergeCells`), so
 * both agree on what "free" means. `excludeKey` skips one entry's own
 * placement — pass the entry being resized so it doesn't block itself.
 *
 * @param children - Grid children whose placements may occupy the region.
 * @param rect - Grid region to test.
 * @param excludeKey - Stable key whose placement should be ignored.
 * @returns Whether no explicit placement overlaps the region.
 */
export function rectIsFree(
  children: GridEntry[],
  rect: CellRect,
  excludeKey: string | null = null
): boolean {
  for (const child of children) {
    if (excludeKey && entryKey(child) === excludeKey) {
      continue;
    }
    if (entryCoversRect(child, rect)) {
      return false;
    }
  }
  return true;
}

/**
 * The CSS Grid line shorthand an entry currently occupies, defaulting to
 * `"auto"` for either axis it doesn't pin.
 *
 * @param entry - Grid entry whose placement should be read.
 * @returns The normalized column and row shorthands.
 */
function placementOf(entry: GridEntry): GridPlacementRef {
  const grid = entry.containerArgs?.grid;
  return { column: grid?.column ?? "auto", row: grid?.row ?? "auto" };
}

/**
 * The final placement rects of every grid child after a decision is
 * applied: untouched children keep their rects, cascaded children take
 * their moved rects, the source lands at `sourceLanding`. A same-grid
 * source is dropped from the untouched set (it's re-placed via
 * `sourceLanding`). Used only to derive the post-drop declared size.
 *
 * @param kids - Current target-grid children.
 * @param sourceKey - Stable key of an existing source.
 * @param inGrid - Whether the source currently belongs to this grid.
 * @param moves - Cascade displacements to apply.
 * @param sourceLanding - Placement assigned to the source.
 * @returns The placements after applying the decision.
 */
function finalRects(
  kids: GridEntry[],
  sourceKey: string | null,
  inGrid: boolean,
  moves: GridDropMove[],
  sourceLanding: GridPlacementRef | null
): GridPlacementRef[] {
  const moveMap = new Map(moves.map((move) => [move.slotKey, move]));
  const rects: GridPlacementRef[] = [];
  for (const child of kids) {
    const key = entryKey(child);
    if (inGrid && key === sourceKey) {
      continue;
    }
    const moved = key == null ? undefined : moveMap.get(key);
    if (moved) {
      rects.push({ column: moved.column, row: moved.row });
    } else {
      const grid = child.containerArgs?.grid;
      rects.push({ column: grid?.column ?? "auto", row: grid?.row ?? "auto" });
    }
  }
  if (sourceLanding) {
    rects.push(sourceLanding);
  }
  return rects;
}

/**
 * The declared dimensions that fit `rects` — `gridDimensions` over the
 * resulting placements, so declared grows to match usage but never shrinks
 * below the input declared size.
 *
 * @param declared - Persisted dimensions before the drop.
 * @param rects - Placements present after the drop.
 * @returns Dimensions large enough to contain every placement.
 */
function declaredFromRects(
  declared: GridDimensions,
  rects: GridPlacementRef[]
): GridDimensions {
  const pseudoChildren = rects.map((rect) => ({
    containerArgs: { grid: { column: rect.column, row: rect.row } },
  }));
  return gridDimensions(declared, pseudoChildren);
}

/**
 * Creates a no-op decision with unchanged dimensions.
 *
 * @param declared - Persisted dimensions to preserve.
 * @returns A decision that performs no placement.
 */
function noop(declared: GridDimensions): GridDropDecision {
  return {
    action: GRID_DROP_ACTIONS.NOOP,
    placement: null,
    moves: [],
    swapWith: null,
    declared: { columns: declared.columns, rows: declared.rows },
  };
}
