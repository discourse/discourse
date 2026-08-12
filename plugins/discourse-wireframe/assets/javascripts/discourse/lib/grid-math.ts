// Editor-only grid geometry: the drag / occupation / shift logic the editor
// uses. `parsePlacement` (the one parser this module needs internally) comes
// from core's public blocks API. `entryKey` is imported from its own file
// rather than `./mutate-layout` to avoid pulling the rest of mutate-layout's
// helpers in alongside it.
import { LAYOUT_MERGED_CELL_BLOCK, parsePlacement } from "discourse/blocks";
import type { LayoutEntry } from "discourse/blocks/types";
import type {
  SlotPlacement,
  Track,
} from "discourse/lib/blocks/-internals/grid-placement";
import { entryKey } from "./entry-key";

/**
 * The grid placement hints a child entry carries under `containerArgs.grid`.
 * `column` / `row` are CSS Grid line shorthand strings (e.g. `"1 / 4"`);
 * `align` / `justify` are the per-cell alignment keywords.
 */
export interface GridPlacementArgs {
  /** CSS Grid column-line shorthand. */
  column?: string;
  /** CSS Grid row-line shorthand. */
  row?: string;
  /** Cross-axis alignment within the cell. */
  align?: string;
  /** Main-axis alignment within the cell. */
  justify?: string;
}

/**
 * A child entry's container args, refined for grid mode. The grid layout
 * namespaces its per-child placement hints under `grid`; the index signature
 * keeps this compatible with the generic `Record<string, unknown>` container
 * args the parser and other layout modes expect.
 */
export interface GridContainerArgs {
  /** Grid placement namespace. */
  grid?: GridPlacementArgs;
  /** Arguments belonging to another container mode. */
  [key: string]: unknown;
}

/**
 * A grid child entry as the editor manipulates it — a `LayoutEntry` whose
 * `containerArgs` are refined to the grid-mode shape, plus the stable key the
 * editor stamps on live entries so `entryKey` can address them.
 */
export interface GridEntry extends Omit<LayoutEntry, "containerArgs"> {
  /** Container arguments refined with grid placement. */
  containerArgs?: GridContainerArgs;
  /** Runtime stable identity assigned by the block pipeline. */
  __stableKey?: string | number;
}

/** A grid-mode layout entry with grid-refined direct children. */
export interface GridLayoutEntry extends Omit<LayoutEntry, "children"> {
  /** Direct children placed or auto-flowed within the grid. */
  children?: GridEntry[];
}

/** An integer grid cell: 1-indexed column / row lines. */
export interface Cell {
  /** One-based grid column. */
  column: number;
  /** One-based grid row. */
  row: number;
}

/** A cell expressed as CSS Grid line shorthand strings (e.g. `"1 / 4"`). */
export interface CellRect {
  /** CSS Grid column-line shorthand. */
  column: string;
  /** CSS Grid row-line shorthand. */
  row: string;
}

/** A cell's placement as resolved (non-null) start / end line numbers. */
export interface EdgeRect {
  /** Exclusive-start/end grid column lines. */
  column: {
    /** Inclusive starting column line. */
    start: number;
    /** Exclusive ending column line. */
    end: number;
  };
  /** Exclusive-start/end grid row lines. */
  row: {
    /** Inclusive starting row line. */
    start: number;
    /** Exclusive ending row line. */
    end: number;
  };
}

/** The four cardinal edges an occupant can be dropped against. */
export type Direction = "left" | "right" | "up" | "down";

/** A compass resize direction — an edge (`n`/`s`/`e`/`w`) or a corner. */
export type ResizeDirection = "n" | "s" | "e" | "w" | "ne" | "nw" | "se" | "sw";

/** Internal integer rectangle used by the cascade / shift planner. */
type Rect = {
  /** Inclusive starting column line. */
  colStart: number;
  /** Exclusive ending column line. */
  colEnd: number;
  /** Inclusive starting row line. */
  rowStart: number;
  /** Exclusive ending row line. */
  rowEnd: number;
};

/** The cascade axis a shift travels along. */
type Axis = "column" | "row";

/** A single slot move in a shift plan: the slot's key and its new placement. */
export interface ShiftMove {
  /** Stable key of the displaced slot. */
  slotKey: string;
  /** Replacement column-line shorthand. */
  column: string;
  /** Replacement row-line shorthand. */
  row: string;
}

/** The result of `computeShiftPlan`: slot moves plus where the source lands. */
export interface ShiftPlan {
  /** Existing slots displaced by the cascade. */
  moves: ShiftMove[];
  /** Placement assigned to the dropped source. */
  sourceLanding: {
    /** Source column-line shorthand. */
    column: string;
    /** Source row-line shorthand. */
    row: string;
  };
}

/** Arguments for `computeShiftPlan`. */
export interface ShiftPlanArgs {
  /** Current explicitly positioned grid entries. */
  slots?: GridEntry[] | null;
  /** Stable key of an in-grid source, or `null` for a new source. */
  sourceKey: string | null;
  /** Stable key of the slot under the drop, when any. */
  dropSlotKey: string | null;
  /** Grid cell under the drop. */
  dropCell?: Cell | null;
  /** Axis and direction in which existing slots move. */
  direction: Direction;
  /** Current effective grid dimensions. */
  gridDims: {
    /** Effective column count. */
    columns: number;
    /** Effective row count. */
    rows: number;
  };
  /** Whether the cascade may extend the grid. */
  allowGrow?: boolean;
}

/** Arguments for `computeSpanResize`. */
export interface SpanResizeArgs {
  /** Original resolved slot rectangle. */
  origin: EdgeRect;
  /** Cell currently under the resize pointer. */
  cell: Cell;
  /** Edge or corner being dragged. */
  direction: ResizeDirection;
  /** Effective grid column count. */
  columns: number;
  /** Effective grid row count. */
  rows: number;
  /** Occupied cells that constrain growth. */
  occupied?: Set<string>;
}

/** Arguments for `resizableDirections`. */
export interface ResizableDirectionsArgs {
  /** Original slot placement. */
  origin: SlotPlacement;
  /** Effective grid column count. */
  columns: number;
  /** Effective grid row count. */
  rows: number;
  /** Occupied cells that constrain growth. */
  occupied: Set<string>;
}

/** Arguments for a single cascade attempt. */
type CascadeArgs = {
  /** Mutable slot rectangles keyed by stable slot identity. */
  rects: Map<string, Rect>;
  /** One-based landing column. */
  landingCol: number;
  /** One-based landing row. */
  landingRow: number;
  /** Axis along which the cascade advances. */
  axis: Axis;
  /** Whether the cascade advances toward increasing track numbers. */
  cascadeForward: boolean;
  /** Maximum permitted column. */
  maxCol: number;
  /** Maximum permitted row. */
  maxRow: number;
};

/**
 * Whether an entry is a "merged cell" — the core `layout-merged-cell` block, an
 * empty positioned region in a grid. Merged cells live in the same `children`
 * array as content but hold no block; this predicate is the one place that
 * distinguishes them from content.
 *
 * @param entry - Grid entry to classify.
 * @returns Whether the entry is a merged-cell placeholder.
 */
export function isMergedCell(entry: GridEntry | null | undefined): boolean {
  return entry?.block === LAYOUT_MERGED_CELL_BLOCK;
}

/**
 * The content children of a grid — everything that isn't a merged cell. Used by
 * the few operations that reason about real content (reflow reading order,
 * "is the grid empty", template matching).
 *
 * @param children - Grid children to filter.
 * @returns The non-placeholder children.
 */
export function contentCells(
  children: GridEntry[] | null | undefined
): GridEntry[] {
  return (children ?? []).filter((child) => !isMergedCell(child));
}

/**
 * Pure helpers for the grid editor. All functions operate on plain data
 * — no DOM access — so they're trivially unit-testable.
 *
 * The grid is 1-indexed (matching CSS Grid's `grid-column` / `grid-row`
 * line numbering). A cell at column C, row R is referred to as
 * `{column: C, row: R}` in the API.
 */

/**
 * Formats a track as a CSS Grid shorthand string suitable for writing
 * to `args.column` / `args.row`. Returns `"auto"` for null-valued
 * tracks so the serialised arg stays predictable.
 *
 * @param track - Parsed track to format.
 * @returns CSS Grid shorthand for the track.
 */
export function formatTrack(track: Track | null | undefined): string {
  if (!track || track.start == null) {
    return "auto";
  }
  if (track.end == null || track.end <= track.start + 1) {
    return `${track.start}`;
  }
  return `${track.start} / ${track.end}`;
}

/**
 * Computes the set of `(row, column)` cells occupied by the given
 * slots. Cells are keyed as `"R,C"` strings for cheap Set lookup.
 *
 * Explicitly-placed slots fill their declared cell rectangle. Slots
 * with auto placement are assigned to the next free cell in document
 * order — an approximation of CSS Grid's auto-flow that's good enough
 * to surface "+" placeholders only where authors haven't already
 * placed content.
 *
 * @param slots - Child entries of a grid layout. Reads each entry's
 *   `containerArgs.grid.column` / `.row`.
 * @param columns - Effective grid column count.
 * @param rows - Effective grid row count.
 * @returns Keys for every occupied cell.
 */
export function computeOccupation(
  slots: GridEntry[] | null | undefined,
  columns: number,
  rows: number
): Set<string> {
  const occupied = new Set<string>();
  const autoSlots: GridEntry[] = [];

  for (const slot of slots ?? []) {
    const placement = parsePlacement(slot.containerArgs);
    if (placement.column.start != null && placement.row.start != null) {
      fillRect(occupied, placement, columns, rows);
    } else {
      autoSlots.push(slot);
    }
  }

  // Approximate CSS Grid auto-flow: walk the grid in row-major order,
  // assign each auto-placed slot to the first unoccupied cell. We
  // iterate by index rather than `for...of` because the loop variable
  // is unused — eslint flags the convenience binding otherwise.
  let cursor = nextFreeCell(occupied, columns, rows, { row: 1, column: 1 });
  for (let i = 0; i < autoSlots.length; i++) {
    if (!cursor) {
      break;
    }
    occupied.add(cellKey(cursor.row, cursor.column));
    cursor = nextFreeCell(occupied, columns, rows, advance(cursor, columns));
  }
  return occupied;
}

/**
 * Returns the list of unoccupied cells as `{column, row}` objects.
 * Convenience wrapper for the overlay's `+` placeholders.
 *
 * @param occupied - Keys for cells already occupied.
 * @param columns - Effective grid column count.
 * @param rows - Effective grid row count.
 * @returns Free cells in reading order.
 */
export function unoccupiedCells(
  occupied: Set<string>,
  columns: number,
  rows: number
): Cell[] {
  const cells: Cell[] = [];
  for (let row = 1; row <= rows; row++) {
    for (let column = 1; column <= columns; column++) {
      if (!occupied.has(cellKey(row, column))) {
        cells.push({ column, row });
      }
    }
  }
  return cells;
}

/**
 * The next free cell in reading order (row-major: top to bottom, left to
 * right) for a grid of the given size, or `null` when every cell is
 * occupied. Wraps `computeOccupation` + the row-major scan so callers that
 * only have the children + dimensions get the "where does the next block
 * land" answer without reaching into the occupation internals. This is the
 * single source of the "next free slot" placement rule.
 *
 * @param children - The grid's current children (exclude the entering block,
 *   so it doesn't occupy its own target).
 * @param dimensions - Effective grid dimensions.
 * @returns The first free cell, or `null` when the grid is full.
 */
export function nextFreeCellInReadingOrder(
  children: GridEntry[] | null | undefined,
  {
    columns,
    rows,
  }: {
    /** Effective grid column count. */
    columns: number;
    /** Effective grid row count. */
    rows: number;
  }
): Cell | null {
  const occupied = computeOccupation(children, columns, rows);
  return nextFreeCell(occupied, columns, rows, { row: 1, column: 1 });
}

/**
 * Builds the ordered list of cells for a free-form grid — every cell of
 * a `columns × rows` grid in reading order (row-major: top to bottom,
 * left to right). Each cell is a `{column, row}` rect in CSS Grid line
 * shorthand. Used when reflowing content into a free grid (one with no
 * preset shape): each content block lands in the next cell.
 *
 * @param columns - Grid column count.
 * @param rows - Grid row count.
 * @returns Every single-cell placement in reading order.
 */
export function cellsForFree(columns: number, rows: number): CellRect[] {
  const cells: CellRect[] = [];
  for (let row = 1; row <= rows; row++) {
    for (let column = 1; column <= columns; column++) {
      cells.push({ column: `${column}`, row: `${row}` });
    }
  }
  return cells;
}

/**
 * Reassigns a grid layout's content children onto an ordered list of
 * target `cells`, in reading order, padding the leftover *spanning*
 * cells with empty merged-cell entries. This is the one primitive behind
 * switching templates, toggling free mode, and reordering via the
 * outline: the grid's *shape* changes and existing content is rearranged
 * to fit it top to bottom, left to right.
 *
 * Content is placed in its current reading order (by `row` start, then
 * `column` start — matching the layout block's own `sortedChildren`), so
 * the block that reads first stays first. Fill direction is left to CSS:
 * under `dir="rtl"` the grid flips column 1 to the right automatically,
 * so ascending line numbers read correctly in both directions — no JS
 * reversal needed.
 *
 * Each placed child keeps its other `containerArgs.grid` props (align /
 * justify) and only has its `column` / `row` overwritten with the cell's
 * rect, so a child reflowed into a spanning cell adopts the span.
 * Leftover single cells get no entry — the grid overlay surfaces those
 * geometrically — but leftover spanning cells become merged-cell entries
 * so the span survives save / load.
 *
 * Returns `null` — refusing the reflow — when there is more content than
 * cells, so callers can disable the action rather than drop blocks.
 *
 * @param contentChildren - The layout's content entries (exclude empty
 *   merged-cell entries before calling).
 * @param cells - Target rects in reading order.
 * @returns The new `children` array, or `null` when the content does not fit.
 */
export function reflowChildrenIntoCells(
  contentChildren: GridEntry[] | null | undefined,
  cells: CellRect[]
): GridEntry[] | null {
  const content = [...(contentChildren ?? [])].sort(readingOrder);
  if (content.length > cells.length) {
    return null;
  }
  const children: GridEntry[] = [];
  for (let i = 0; i < cells.length; i++) {
    const cell = cells[i];
    const child = content[i];
    if (child) {
      children.push({
        ...child,
        containerArgs: {
          ...child.containerArgs,
          grid: {
            ...child.containerArgs?.grid,
            column: cell.column,
            row: cell.row,
          },
        },
      });
    } else if (isMultiCell(cell)) {
      children.push({
        block: LAYOUT_MERGED_CELL_BLOCK,
        containerArgs: {
          grid: {
            column: cell.column,
            row: cell.row,
            align: "stretch",
            justify: "stretch",
          },
        },
      });
    }
  }
  return children;
}

/**
 * Re-derives a grid's content placements from document (array) order:
 * the content children, taken in array order, are reassigned to the
 * positions they currently occupy sorted in reading order (top to
 * bottom, left to right). Empty merged-cell entries keep their rects.
 *
 * This is what makes reordering the children array — e.g. dragging a
 * row in the outline — actually move blocks in the grid: array order
 * becomes reading order, so the first child reads top-left. The set of
 * occupied positions is unchanged (no block moves to a new cell that
 * wasn't already in use), only which block sits in each; spanning
 * positions are preserved, so a block reassigned to a spanning slot
 * adopts the span. A no-op when there are fewer than two content
 * children (nothing to reorder).
 *
 * @param children - The grid's children, in array order.
 * @returns New children with content placements resynced.
 */
export function syncContentToArrayOrder(
  children: GridEntry[] | null | undefined
): GridEntry[] {
  const list = children ?? [];
  const content = contentCells(list);
  if (content.length < 2) {
    return list;
  }
  // The positions content currently occupies, in reading order.
  const rects = content
    .map((child) => ({
      column: child.containerArgs?.grid?.column ?? "auto",
      row: child.containerArgs?.grid?.row ?? "auto",
    }))
    .sort(rectReadingOrder);
  // Walk the array; each content child (in array order) claims the next
  // reading-order position. Merged-cell placeholders pass through untouched.
  let cursor = 0;
  return list.map((child) => {
    if (isMergedCell(child)) {
      return child;
    }
    const rect = rects[cursor++];
    return {
      ...child,
      containerArgs: {
        ...child.containerArgs,
        grid: {
          ...child.containerArgs?.grid,
          column: rect.column,
          row: rect.row,
        },
      },
    };
  });
}

/**
 * Computes new column fractions when the gridline between two adjacent
 * columns is dragged. `deltaPx` is the pixels the left track grows by
 * (negative shrinks it). Two modes:
 *
 *  - **split-pane** (default): the delta moves between the two tracks
 *    adjacent to the line only — the left grows, the immediate right
 *    shrinks, every other track untouched.
 *  - **proportional** (`opts.proportional`): the left track grows by the
 *    delta and ALL tracks to its right shrink in proportion to their
 *    current size (keeping their relative ratios); tracks to the LEFT of
 *    the line are untouched.
 *
 * The drag is clamped so no affected track falls below `minPx`. The
 * resulting pixel widths are converted to `fr` ratios normalised so an
 * evenly-split grid reads `[1, 1, …]`, then snapped to a 0.05 step to
 * keep stored values clean. Returns all-`1` (a balanced grid) when the
 * line index is out of range — callers only ever pass interior lines,
 * this is just a guard. (For a two-column grid the modes coincide.)
 *
 * @param pxWidths - Current resolved column widths, in px.
 * @param leftTrack - 0-indexed track on the LEFT of the dragged line (the
 *   line sits between `leftTrack` and `leftTrack + 1`).
 * @param deltaPx - Pixels the left track grows by.
 * @param options - Minimum-width and proportional-resize options.
 * @returns A fraction per column, length `pxWidths.length`.
 */
export function resizeColumnFractions(
  pxWidths: number[] | null | undefined,
  leftTrack: number,
  deltaPx: number,
  {
    minPx = 24,
    proportional = false,
  }: {
    /** Minimum permitted pixel width for an affected track. */
    minPx?: number;
    /** Whether every track to the right shares the resize delta. */
    proportional?: boolean;
  } = {}
): number[] {
  const widths = (pxWidths ?? []).map((w) =>
    Number.isFinite(w) && w > 0 ? w : 0
  );
  const n = widths.length;
  if (leftTrack < 0 || leftTrack + 1 >= n) {
    return widths.map(() => 1);
  }
  const maxShrink = Math.max(0, widths[leftTrack] - minPx);
  if (proportional) {
    // Grow the left track against ALL tracks to its right, kept in
    // proportion. The most the right side can give up is everything
    // above each track's minimum.
    const rightCount = n - (leftTrack + 1);
    let rightTotal = 0;
    for (let j = leftTrack + 1; j < n; j++) {
      rightTotal += widths[j];
    }
    const maxGrow = Math.max(0, rightTotal - rightCount * minPx);
    const delta = clamp(deltaPx, -maxShrink, maxGrow);
    widths[leftTrack] += delta;
    const scale = rightTotal > 0 ? (rightTotal - delta) / rightTotal : 1;
    for (let j = leftTrack + 1; j < n; j++) {
      widths[j] *= scale;
    }
  } else {
    const maxGrow = Math.max(0, widths[leftTrack + 1] - minPx);
    const delta = clamp(deltaPx, -maxShrink, maxGrow);
    widths[leftTrack] += delta;
    widths[leftTrack + 1] -= delta;
  }
  const total = widths.reduce((sum, w) => sum + w, 0) || n;
  // Normalise so the average track is `1fr` (a balanced grid → all 1s),
  // then snap to a 0.05 step so a drag leaves a clean, stable value.
  // (`* 20 / 20` rather than `/ 0.05 * 0.05` — the latter reintroduces
  // float noise, e.g. `24 * 0.05 === 1.2000000000000002`.)
  return widths.map((w) => Math.round((w / total) * n * 20) / 20);
}

/**
 * Resolves the cell `{column, row}` under a pointer event, given the
 * grid container's bounding rect. Used by the drag handlers to compute
 * snap targets.
 *
 * @param event - Pointer viewport coordinates.
 * @param gridRect - Grid container bounds.
 * @param columns - Effective grid column count.
 * @param rows - Effective grid row count.
 * @returns The one-based cell under the pointer.
 */
export function cellAt(
  event: {
    /** Pointer x-coordinate in viewport pixels. */
    clientX: number;
    /** Pointer y-coordinate in viewport pixels. */
    clientY: number;
  },
  gridRect: DOMRect,
  columns: number,
  rows: number
): Cell {
  const x = event.clientX - gridRect.left;
  const y = event.clientY - gridRect.top;
  const cellWidth = gridRect.width / columns;
  const cellHeight = gridRect.height / rows;
  const column = clamp(Math.floor(x / cellWidth) + 1, 1, columns);
  const row = clamp(Math.floor(y / cellHeight) + 1, 1, rows);
  return { column, row };
}

/**
 * Computes the new placement for a directional span-resize gesture: the
 * author grabbed one of a cell's edge / corner handles and dragged toward
 * `cell`. The direction code names which edges move — `e` / `w` move the
 * trailing / leading column edge, `s` / `n` move the trailing / leading row
 * edge, and corner codes (`se`, `nw`, …) move one edge per axis. The opposite
 * edges stay pinned, so the cell grows or shrinks from the grabbed side.
 *
 * Pure function (no DOM), extracted so the geometry is unit-testable.
 *
 * Grid lines are 1-indexed and the trailing edge is exclusive: a cell at line
 * `N` occupies the track between lines `N` and `N + 1`, so the pointer cell `c`
 * yields a trailing edge of `c + 1` and a leading edge of `c`. Every edge is
 * clamped to the grid bounds and to a minimum 1×1 span.
 *
 * A GROWING edge additionally clamps at the first occupied cell in its path,
 * so a span can never overlap a neighbour — it stops one track short. Shrinking
 * frees cells, so it never needs an occupancy clamp. The column extent is
 * clamped first (against the candidate row band) and the row extent second
 * (against the already-clamped column band), so a diagonal obstacle pulls
 * whichever edge reaches it rather than allowing an overlap to slip through.
 *
 * @param params - Parameters:
 *   - `origin` - The cell's current placement (assumed to be a valid,
 *     non-overlapping rect).
 *   - `cell` - The pointer's cell.
 *   - `direction` - One of `n|s|e|w|ne|nw|se|sw`.
 *   - `columns` - The grid's column count.
 *   - `rows` - The grid's row count.
 *   - `occupied` - Cells occupied by OTHER entries (exclude the resized cell),
 *     keyed by `cellKey`. Defaults to empty (no occupancy clamp).
 */
export function computeSpanResize({
  origin,
  cell,
  direction,
  columns,
  rows,
  occupied,
}: SpanResizeArgs): EdgeRect {
  const occ = occupied ?? new Set<string>();
  const east = direction.includes("e");
  const west = direction.includes("w");
  const south = direction.includes("s");
  const north = direction.includes("n");

  let colStart = origin.column.start;
  let colEnd = origin.column.end;
  let rowStart = origin.row.start;
  let rowEnd = origin.row.end;

  // Candidate edges from the pointer cell, clamped to the grid and a 1×1 floor.
  if (east) {
    colEnd = clamp(cell.column + 1, origin.column.start + 1, columns + 1);
  } else if (west) {
    colStart = clamp(cell.column, 1, origin.column.end - 1);
  }
  if (south) {
    rowEnd = clamp(cell.row + 1, origin.row.start + 1, rows + 1);
  } else if (north) {
    rowStart = clamp(cell.row, 1, origin.row.end - 1);
  }

  // Occupancy clamp on growing edges only (column first, then row).
  if (east && colEnd > origin.column.end) {
    for (let c = origin.column.end; c < colEnd; c++) {
      if (columnBlocked(occ, c, rowStart, rowEnd)) {
        colEnd = c;
        break;
      }
    }
  } else if (west && colStart < origin.column.start) {
    for (let c = origin.column.start - 1; c >= colStart; c--) {
      if (columnBlocked(occ, c, rowStart, rowEnd)) {
        colStart = c + 1;
        break;
      }
    }
  }
  if (south && rowEnd > origin.row.end) {
    for (let r = origin.row.end; r < rowEnd; r++) {
      if (rowBlocked(occ, r, colStart, colEnd)) {
        rowEnd = r;
        break;
      }
    }
  } else if (north && rowStart < origin.row.start) {
    for (let r = origin.row.start - 1; r >= rowStart; r--) {
      if (rowBlocked(occ, r, colStart, colEnd)) {
        rowStart = r + 1;
        break;
      }
    }
  }

  return {
    column: { start: colStart, end: colEnd },
    row: { start: rowStart, end: rowEnd },
  };
}

/**
 * The compass directions a cell can effectively resize from its current rect.
 * A direction is included when its edge can GROW (the adjacent cell band is in
 * bounds and unoccupied) OR SHRINK (that axis spans more than one cell); a
 * corner is included only when both of its edges are. Used to render only the
 * handles that would actually move the cell. A 1×1 origin can never shrink, so
 * it yields only the directions that have a free neighbour to grow into.
 *
 * @param params - Parameters:
 *   - `origin` - The cell's current placement.
 *   - `columns` - Effective column count.
 *   - `rows` - Effective row count.
 *   - `occupied` - Cells occupied by OTHER entries, keyed `"row,col"` (the
 *     origin's own cells must not be in this set).
 * @returns A subset of `["n","e","s","w","ne","nw","se","sw"]`.
 */
export function resizableDirections({
  origin,
  columns,
  rows,
  occupied,
}: ResizableDirectionsArgs): ResizeDirection[] {
  const { column, row } = origin;
  if (
    column.start == null ||
    column.end == null ||
    row.start == null ||
    row.end == null
  ) {
    return [];
  }
  const colSpan = column.end - column.start;
  const rowSpan = row.end - row.start;

  // Growth reaches the adjacent cell band: east/south extend past the trailing
  // line, west/north past the leading line. Shrinking only needs span > 1.
  const east =
    colSpan > 1 ||
    (column.end <= columns &&
      !columnBlocked(occupied, column.end, row.start, row.end));
  const west =
    colSpan > 1 ||
    (column.start > 1 &&
      !columnBlocked(occupied, column.start - 1, row.start, row.end));
  const north =
    rowSpan > 1 ||
    (row.start > 1 &&
      !rowBlocked(occupied, row.start - 1, column.start, column.end));
  const south =
    rowSpan > 1 ||
    (row.end <= rows &&
      !rowBlocked(occupied, row.end, column.start, column.end));

  const dirs: ResizeDirection[] = [];
  if (north) {
    dirs.push("n");
  }
  if (east) {
    dirs.push("e");
  }
  if (south) {
    dirs.push("s");
  }
  if (west) {
    dirs.push("w");
  }
  if (north && east) {
    dirs.push("ne");
  }
  if (north && west) {
    dirs.push("nw");
  }
  if (south && east) {
    dirs.push("se");
  }
  if (south && west) {
    dirs.push("sw");
  }
  return dirs;
}

/**
 * Whether any cell in column `column` across rows `[rowStart, rowEnd)` is
 * occupied. Rows / columns are 1-indexed cell indices (a track's leading line).
 *
 * @param occupied - Keys for cells already occupied.
 * @param column - Column to scan.
 * @param rowStart - Inclusive first row.
 * @param rowEnd - Exclusive final row.
 * @returns Whether the scanned column band is occupied.
 */
function columnBlocked(
  occupied: Set<string>,
  column: number,
  rowStart: number,
  rowEnd: number
): boolean {
  for (let r = rowStart; r < rowEnd; r++) {
    if (occupied.has(cellKey(r, column))) {
      return true;
    }
  }
  return false;
}

/**
 * Whether any cell in row `row` across columns `[colStart, colEnd)` is
 * occupied.
 *
 * @param occupied - Keys for cells already occupied.
 * @param row - Row to scan.
 * @param colStart - Inclusive first column.
 * @param colEnd - Exclusive final column.
 * @returns Whether the scanned row band is occupied.
 */
function rowBlocked(
  occupied: Set<string>,
  row: number,
  colStart: number,
  colEnd: number
): boolean {
  for (let c = colStart; c < colEnd; c++) {
    if (occupied.has(cellKey(row, c))) {
      return true;
    }
  }
  return false;
}

/**
 * Five-zone hit test inside a cell. Returns `"center"` for the inner
 * 60% rect, otherwise one of `"left"` / `"right"` / `"up"` / `"down"`
 * (the outer 20% bands). Corners resolve to whichever edge the cursor
 * is RELATIVELY closer to — `x/w` vs `y/h` rather than absolute pixels
 * — so a hover on the left edge of a tall narrow cell stays `"left"`
 * instead of biasing toward `"up"` / `"down"` near the corners.
 *
 * @param x - Cursor X within the cell (0 at the left edge).
 * @param y - Cursor Y within the cell (0 at the top edge).
 * @param w - Cell width.
 * @param h - Cell height.
 */
export function computeZone(
  x: number,
  y: number,
  w: number,
  h: number
): "center" | "left" | "right" | "up" | "down" {
  const edge = 0.2;
  const fromLeft = x / w;
  const fromRight = (w - x) / w;
  const fromTop = y / h;
  const fromBottom = (h - y) / h;
  const minFromEdge = Math.min(fromLeft, fromRight, fromTop, fromBottom);

  if (minFromEdge > edge) {
    return "center";
  }
  if (minFromEdge === fromLeft) {
    return "left";
  }
  if (minFromEdge === fromRight) {
    return "right";
  }
  if (minFromEdge === fromTop) {
    return "up";
  }
  return "down";
}

/**
 * Three-zone Y-axis hit test for the collapsed (single-column) view.
 * Left / right carry no meaning in a vertical stack — only `"up"`
 * (insert above), `"center"` (swap / move into), and `"down"` (insert
 * below) do. Returns `"center"` for a zero-height element.
 *
 * @param y - Cursor Y within the element (0 at the top edge).
 * @param h - Element height.
 */
export function computeZoneCollapsed(
  y: number,
  h: number
): "up" | "center" | "down" {
  const edge = 0.25;
  if (h <= 0) {
    return "center";
  }
  const fromTop = y / h;
  if (fromTop < edge) {
    return "up";
  }
  if (fromTop > 1 - edge) {
    return "down";
  }
  return "center";
}

/**
 * Returns `true` when two slot placements occupy any shared cells. Both
 * placements must be EXPLICIT (their `column.start` / `row.start` set);
 * auto placements report `false` because CSS Grid's auto-flow handles
 * them without colliding into explicitly-placed neighbours.
 *
 * Used by chrome decoration to flag visually-overlapping blocks so the
 * author notices an accidental resize past a neighbour.
 *
 * @param a - First parsed placement.
 * @param b - Second parsed placement.
 * @returns Whether both explicit placements overlap.
 */
export function placementsOverlap(
  a: SlotPlacement | null | undefined,
  b: SlotPlacement | null | undefined
): boolean {
  if (
    a?.column?.start == null ||
    a.column.end == null ||
    a?.row?.start == null ||
    a.row.end == null ||
    b?.column?.start == null ||
    b.column.end == null ||
    b?.row?.start == null ||
    b.row.end == null
  ) {
    return false;
  }
  return (
    a.column.start < b.column.end &&
    b.column.start < a.column.end &&
    a.row.start < b.row.end &&
    b.row.start < a.row.end
  );
}

/**
 * Computes the slot mutations needed to insert a new occupant at an
 * edge of `dropSlotKey`, cascading existing slots away in the relevant
 * direction until an empty cell absorbs them. Returns `null` if the
 * shift can't fit (cascade walks off the grid, or a shifted slot
 * collides with a non-cascadable neighbour).
 *
 * With `allowGrow`, a cascade that would otherwise run off the trailing
 * edge instead GROWS that axis by one track (a column for a horizontal
 * cascade, a row for a vertical one) and lands there — the "add a column
 * when the row is full" rule. Growth is a fallback: it only fires when
 * neither the forward nor the backward cascade fits at the current size,
 * so an empty cell within the grid still absorbs the cascade first.
 *
 * Edge / direction mapping:
 *
 *  - `"left"` → source lands at dropSlot's leftmost cell; dropSlot and
 *     anything past it in the row cascade RIGHT.
 *  - `"right"` → source lands just past dropSlot's right edge; the slot
 *     at that cell (if any) cascades RIGHT.
 *  - `"up"` → source lands at dropSlot's topmost cell; dropSlot
 *     cascades DOWN.
 *  - `"down"` → source lands just past dropSlot's bottom edge; the slot
 *     at that cell (if any) cascades DOWN.
 *
 * The source's own cells (if `sourceKey` is non-null and the source is
 * already in the grid) are treated as vacant during planning — this
 * is what lets the canonical `A, B, C → C, A, B` rearrange succeed:
 * C's old cell absorbs B's shift.
 *
 * Assumes the source lands as 1×1; multi-span sources from other grids
 * (or the same grid) land 1×1 here and the author can resize.
 *
 * @param args - Grid state and requested cascade geometry.
 * @returns The cascade plan, or `null` when no valid shift fits.
 */
export function computeShiftPlan({
  slots,
  sourceKey,
  dropSlotKey,
  dropCell,
  direction,
  gridDims,
  allowGrow = false,
}: ShiftPlanArgs): ShiftPlan | null {
  const maxCol = gridDims.columns;
  const maxRow = gridDims.rows;

  // Build rect index, dropping the source's rect (treated as vacant).
  const rects = new Map<string, Rect>();
  for (const slot of slots ?? []) {
    const key = entryKey(slot);
    if (!key || key === sourceKey) {
      continue;
    }
    const placement = parsePlacement(slot.containerArgs);
    if (placement.column.start == null || placement.row.start == null) {
      continue;
    }
    rects.set(key, {
      colStart: placement.column.start,
      colEnd: placement.column.end ?? placement.column.start + 1,
      rowStart: placement.row.start,
      rowEnd: placement.row.end ?? placement.row.start + 1,
    });
  }

  // Drop rect: either an existing slot's rect, or a virtual 1×1 at a
  // cell coordinate (for empty-cell edge drops). The shift algorithm
  // doesn't care which — it only needs a rectangle to anchor the
  // landing position and cascade direction.
  let dropRect: Rect | undefined;
  if (dropSlotKey) {
    dropRect = rects.get(dropSlotKey);
    if (!dropRect) {
      return null;
    }
  } else if (dropCell) {
    dropRect = {
      colStart: dropCell.column,
      colEnd: dropCell.column + 1,
      rowStart: dropCell.row,
      rowEnd: dropCell.row + 1,
    };
  } else {
    return null;
  }

  // Landing position and cascade axis.
  let landingCol: number;
  let landingRow: number;
  let axis: Axis;
  if (direction === "left") {
    landingCol = dropRect.colStart;
    landingRow = dropRect.rowStart;
    axis = "column";
  } else if (direction === "right") {
    landingCol = dropRect.colEnd;
    landingRow = dropRect.rowStart;
    axis = "column";
  } else if (direction === "up") {
    landingCol = dropRect.colStart;
    landingRow = dropRect.rowStart;
    axis = "row";
  } else {
    // "down"
    landingCol = dropRect.colStart;
    landingRow = dropRect.rowEnd;
    axis = "row";
  }

  // Remember the un-clamped landing so a grow-retry can place the source
  // in the freshly added track rather than the clamped trailing edge.
  const rawLandingCol = landingCol;
  const rawLandingRow = landingRow;

  // Clamp out-of-bounds landings to the trailing edge of the grid.
  // Without this, dropping on the right edge of the LAST column
  // (e.g. "after C" in a 3-col grid → landingCol = 4) would return
  // null immediately. Clamping to maxCol means the source displaces
  // the trailing slot; the bidirectional cascade below figures out
  // where the displaced slot goes.
  if (landingCol > maxCol) {
    landingCol = maxCol;
  }
  if (landingRow > maxRow) {
    landingRow = maxRow;
  }
  if (landingCol < 1 || landingRow < 1) {
    return null;
  }

  // Try a forward cascade (slots shift +1 on the axis). When the
  // forward cascade walks off the grid (e.g. source is to the LEFT
  // of the landing, so there's no room to push further right), fall
  // back to a backward cascade (slots shift -1, using the space the
  // source vacated). This lets `A, B, C → B, C, A` succeed via the
  // same drop gesture as the symmetric `A, B, C → C, A, B`.
  const forward = _attemptCascade({
    rects,
    landingCol,
    landingRow,
    axis,
    cascadeForward: true,
    maxCol,
    maxRow,
  });
  if (forward) {
    return forward;
  }
  const backward = _attemptCascade({
    rects,
    landingCol,
    landingRow,
    axis,
    cascadeForward: false,
    maxCol,
    maxRow,
  });
  // A backward cascade only earns its keep when it actually displaces
  // something (rotating a neighbour into the cell the source vacated, or
  // rippling into a hole behind the drop). A ZERO-move backward "plan"
  // means scanning behind the landing found nothing — it would drop the
  // source in place and leave content ahead of it untouched, e.g. dropping
  // before the leftmost cell while a block ahead overflows the row. That's
  // not "make room"; reject it so the drop grows the axis (below) instead.
  // An empty plan is only ever legitimate from the forward cascade (a drop
  // into genuinely free space with nothing to shift).
  if (backward && backward.moves.length > 0) {
    return backward;
  }
  if (allowGrow) {
    // The line is full at the current size — grow the cascade axis by one
    // and retry forward, landing at the un-clamped drop position so the
    // source occupies the freshly added track.
    const grownMaxCol = axis === "column" ? maxCol + 1 : maxCol;
    const grownMaxRow = axis === "row" ? maxRow + 1 : maxRow;
    const grown = _attemptCascade({
      rects,
      landingCol: Math.min(rawLandingCol, grownMaxCol),
      landingRow: Math.min(rawLandingRow, grownMaxRow),
      axis,
      cascadeForward: true,
      maxCol: grownMaxCol,
      maxRow: grownMaxRow,
    });
    if (grown) {
      return grown;
    }
  }
  return null;
}

/**
 * One cascade attempt — either forward (shift +1, source's vacated
 * cell is to the RIGHT/BELOW the landing) or backward (shift -1,
 * source's vacated cell is to the LEFT/ABOVE). Returns the move plan
 * if everything fits without overflowing the grid; `null` otherwise.
 *
 * @param args - Rectangles, landing point, axis, direction, and grid bounds.
 * @returns The validated move plan, or `null` when it does not fit.
 */
function _attemptCascade({
  rects,
  landingCol,
  landingRow,
  axis,
  cascadeForward,
  maxCol,
  maxRow,
}: CascadeArgs): ShiftPlan | null {
  // The first slot to displace is whatever overlaps the source's
  // intended landing rect. If that cell is empty, scan along the
  // cascade direction to find the nearest neighbour — that's the
  // "ripple shift" semantic for empty-cell edge drops.
  const firstShifted = _findFirstSlotInDirection(
    rects,
    landingCol,
    landingRow,
    axis,
    maxCol,
    maxRow,
    cascadeForward
  );

  const moves: Array<{
    /** Stable key of the displaced slot. */
    slotKey: string;
    /** Rectangle assigned after displacement. */
    newRect: Rect;
  }> = [];
  const shifted = new Set<string>();
  let cursor = firstShifted;

  while (cursor) {
    if (shifted.has(cursor)) {
      return null;
    }
    shifted.add(cursor);
    const rect = rects.get(cursor);
    if (!rect) {
      return null;
    }
    const newRect = _shiftRect(rect, axis, cascadeForward);
    if (cascadeForward) {
      if (newRect.colEnd > maxCol + 1 || newRect.rowEnd > maxRow + 1) {
        return null;
      }
    } else {
      if (newRect.colStart < 1 || newRect.rowStart < 1) {
        return null;
      }
    }
    moves.push({ slotKey: cursor, newRect });
    let next: string | null = null;
    for (const [key, otherRect] of rects) {
      if (key === cursor || shifted.has(key)) {
        continue;
      }
      if (_rectsOverlap(newRect, otherRect)) {
        next = key;
        break;
      }
    }
    cursor = next;
  }

  // Validate: replay moves and the source's landing onto a fresh map.
  const finalRects = new Map(rects);
  for (const move of moves) {
    finalRects.set(move.slotKey, move.newRect);
  }
  const sourceRect: Rect = {
    colStart: landingCol,
    colEnd: landingCol + 1,
    rowStart: landingRow,
    rowEnd: landingRow + 1,
  };
  for (const [, rect] of finalRects) {
    if (_rectsOverlap(sourceRect, rect)) {
      return null;
    }
  }
  const finalRectValues = [...finalRects.values()];
  for (const [index, rect] of finalRectValues.entries()) {
    for (const other of finalRectValues.slice(index + 1)) {
      if (_rectsOverlap(rect, other)) {
        return null;
      }
    }
  }

  return {
    moves: moves.map((m) => ({
      slotKey: m.slotKey,
      column: _rectToTrackString(m.newRect.colStart, m.newRect.colEnd),
      row: _rectToTrackString(m.newRect.rowStart, m.newRect.rowEnd),
    })),
    sourceLanding: {
      column: `${landingCol}`,
      row: `${landingRow}`,
    },
  };
}

/**
 * Finds the slot covering a cell.
 *
 * @param rects - Slot rectangles keyed by stable identity.
 * @param col - One-based column to inspect.
 * @param row - One-based row to inspect.
 * @returns The covering slot key, or `null` for an empty cell.
 */
function _findSlotAt(
  rects: Map<string, Rect>,
  col: number,
  row: number
): string | null {
  for (const [key, rect] of rects) {
    if (
      col >= rect.colStart &&
      col < rect.colEnd &&
      row >= rect.rowStart &&
      row < rect.rowEnd
    ) {
      return key;
    }
  }
  return null;
}

/**
 * Scans from `(startCol, startRow)` in the given axis (forward
 * direction only — column = right, row = down) and returns the first
 * slot key whose rect covers that cell. Returns `null` if no slot is
 * found before the grid edge. Used to find the head of the cascade
 * chain regardless of whether the drop target itself is a slot or
 * an empty cell.
 *
 * @param rects - Slot rectangles keyed by stable identity.
 * @param startCol - One-based starting column.
 * @param startRow - One-based starting row.
 * @param axis - Axis along which to scan.
 * @param maxCol - Maximum permitted column.
 * @param maxRow - Maximum permitted row.
 * @param cascadeForward - Whether to scan toward increasing track numbers.
 * @returns The first slot key in the scan direction, or `null`.
 */
function _findFirstSlotInDirection(
  rects: Map<string, Rect>,
  startCol: number,
  startRow: number,
  axis: Axis,
  maxCol: number,
  maxRow: number,
  cascadeForward = true
): string | null {
  if (axis === "column") {
    if (cascadeForward) {
      for (let c = startCol; c <= maxCol; c++) {
        const slot = _findSlotAt(rects, c, startRow);
        if (slot) {
          return slot;
        }
      }
    } else {
      for (let c = startCol; c >= 1; c--) {
        const slot = _findSlotAt(rects, c, startRow);
        if (slot) {
          return slot;
        }
      }
    }
  } else {
    if (cascadeForward) {
      for (let r = startRow; r <= maxRow; r++) {
        const slot = _findSlotAt(rects, startCol, r);
        if (slot) {
          return slot;
        }
      }
    } else {
      for (let r = startRow; r >= 1; r--) {
        const slot = _findSlotAt(rects, startCol, r);
        if (slot) {
          return slot;
        }
      }
    }
  }
  return null;
}

/**
 * Shifts a rectangle by one track along an axis.
 *
 * @param rect - Rectangle to shift.
 * @param axis - Axis along which to shift.
 * @param cascadeForward - Whether to shift toward increasing track numbers.
 * @returns The shifted rectangle.
 */
function _shiftRect(rect: Rect, axis: Axis, cascadeForward = true): Rect {
  const delta = cascadeForward ? 1 : -1;
  if (axis === "column") {
    return {
      colStart: rect.colStart + delta,
      colEnd: rect.colEnd + delta,
      rowStart: rect.rowStart,
      rowEnd: rect.rowEnd,
    };
  }
  return {
    colStart: rect.colStart,
    colEnd: rect.colEnd,
    rowStart: rect.rowStart + delta,
    rowEnd: rect.rowEnd + delta,
  };
}

/**
 * Checks whether two internal grid rectangles overlap.
 *
 * @param a - First rectangle.
 * @param b - Second rectangle.
 * @returns Whether the rectangles share any cell.
 */
function _rectsOverlap(a: Rect, b: Rect): boolean {
  return (
    a.colStart < b.colEnd &&
    b.colStart < a.colEnd &&
    a.rowStart < b.rowEnd &&
    b.rowStart < a.rowEnd
  );
}

/**
 * Formats an internal start/end pair as CSS Grid shorthand.
 *
 * @param start - Inclusive starting grid line.
 * @param end - Exclusive ending grid line.
 * @returns The compact track shorthand.
 */
function _rectToTrackString(start: number, end: number): string {
  return end === start + 1 ? `${start}` : `${start} / ${end}`;
}

/**
 * Adds the cells covered by a placement to an occupation set.
 *
 * @param occupied - Set to mutate with occupied cell keys.
 * @param placement - Placement rectangle to add.
 * @param columns - Effective grid column count.
 * @param rows - Effective grid row count.
 */
function fillRect(
  occupied: Set<string>,
  placement: SlotPlacement,
  columns: number,
  rows: number
): void {
  if (
    placement.column.start == null ||
    placement.column.end == null ||
    placement.row.start == null ||
    placement.row.end == null
  ) {
    return;
  }
  const colStart = clamp(placement.column.start, 1, columns);
  const colEnd = clamp(placement.column.end, colStart + 1, columns + 1);
  const rowStart = clamp(placement.row.start, 1, rows);
  const rowEnd = clamp(placement.row.end, rowStart + 1, rows + 1);
  for (let r = rowStart; r < rowEnd; r++) {
    for (let c = colStart; c < colEnd; c++) {
      occupied.add(cellKey(r, c));
    }
  }
}

/**
 * Scans for a free cell in row-major order.
 *
 * @param occupied - Keys for cells already occupied.
 * @param columns - Effective grid column count.
 * @param rows - Effective grid row count.
 * @param start - First cell to inspect.
 * @returns The next free cell, or `null` at the grid boundary.
 */
function nextFreeCell(
  occupied: Set<string>,
  columns: number,
  rows: number,
  start: Cell
): Cell | null {
  let cursor: Cell | null = start;
  while (cursor && cursor.row <= rows) {
    if (!occupied.has(cellKey(cursor.row, cursor.column))) {
      return cursor;
    }
    cursor = advance(cursor, columns);
  }
  return null;
}

/**
 * Advances a row-major cursor by one cell.
 *
 * @param cursor - Current cell.
 * @param columns - Number of columns before wrapping.
 * @returns The following cell.
 */
function advance(cursor: Cell, columns: number): Cell {
  if (cursor.column >= columns) {
    return { row: cursor.row + 1, column: 1 };
  }
  return { row: cursor.row, column: cursor.column + 1 };
}

/**
 * Serializes a cell coordinate for occupation-set lookup.
 *
 * @param row - One-based row.
 * @param column - One-based column.
 * @returns The stable cell key.
 */
function cellKey(row: number, column: number): string {
  return `${row},${column}`;
}

/**
 * Constrains a number to an inclusive range.
 *
 * @param value - Number to constrain.
 * @param min - Inclusive lower bound.
 * @param max - Inclusive upper bound.
 * @returns The constrained number.
 */
function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

/**
 * Reading-order comparator for grid children: top row first, then left
 * column. Mirrors the layout block's `sortedChildren` so the editor and
 * the rendered DOM agree on order. Auto / unset placements sort as the
 * first cell.
 *
 * @param a - First grid entry.
 * @param b - Second grid entry.
 * @returns Comparator result for row-major order.
 */
function readingOrder(a: GridEntry, b: GridEntry): number {
  const pa = parsePlacement(a.containerArgs);
  const pb = parsePlacement(b.containerArgs);
  const ar = pa.row.start ?? 1;
  const br = pb.row.start ?? 1;
  if (ar !== br) {
    return ar - br;
  }
  return (pa.column.start ?? 1) - (pb.column.start ?? 1);
}

/**
 * Reading-order comparator for `{column, row}` cell rects (the same
 * order as `readingOrder`, but keyed off plain rect objects rather than
 * entries). Top row first, then left column.
 *
 * @param a - First cell rectangle.
 * @param b - Second cell rectangle.
 * @returns Comparator result for row-major order.
 */
function rectReadingOrder(a: CellRect, b: CellRect): number {
  const pa = parsePlacement({ grid: a });
  const pb = parsePlacement({ grid: b });
  const ar = pa.row.start ?? 1;
  const br = pb.row.start ?? 1;
  if (ar !== br) {
    return ar - br;
  }
  return (pa.column.start ?? 1) - (pb.column.start ?? 1);
}

/**
 * True when a `{column, row}` cell covers more than one grid track on
 * either axis. A bare line ("2") spans one track; a range ("1 / 4")
 * spans more.
 *
 * @param cell - Cell rectangle to inspect.
 * @returns Whether either axis spans multiple tracks.
 */
function isMultiCell(cell: CellRect): boolean {
  const placement = parsePlacement({ grid: cell });
  const colSpan =
    (placement.column.end ?? placement.column.start + 1) -
    placement.column.start;
  const rowSpan =
    (placement.row.end ?? placement.row.start + 1) - placement.row.start;
  return colSpan > 1 || rowSpan > 1;
}
