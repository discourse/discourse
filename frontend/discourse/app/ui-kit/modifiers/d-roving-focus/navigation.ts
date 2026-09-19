import type { Orientation } from "./types";

/**
 * The result of one navigation step. A row edge consumes the key without leaving the group;
 * a group edge may be reported for handoff. A wrap that lands on the cursor is a row edge so
 * wrapping suppresses boundary reporting without claiming a move.
 */
export type StepOutcome =
  | { kind: "move"; index: number }
  | { kind: "row-edge" }
  | { kind: "group-edge" };

/**
 * Walks a bounded coordinate space by `delta` for the first navigable item.
 *
 * @param items - The coordinate space to walk.
 * @param from - The inclusive starting index.
 * @param delta - The positive or negative stride.
 * @param min - The lowest index the walk may visit.
 * @param max - The highest index the walk may visit.
 * @param isNavigable - Whether the cursor may land on a candidate.
 * @returns The first matching index, or `null` when the walk runs out.
 */
export function scan<T>(
  items: T[],
  from: number,
  delta: number,
  min: number,
  max: number,
  isNavigable: (item: T) => boolean
): number | null {
  for (let index = from; index >= min && index <= max; index += delta) {
    if (isNavigable(items[index])) {
      return index;
    }
  }
  return null;
}

/**
 * Steps along the row axis without crossing a closed grid row.
 *
 * @param index - The cursor position, or a negative value when there is no cursor.
 * @param delta - `1` for forward or `-1` for backward DOM order.
 * @param cells - The coordinate space to move through.
 * @param columns - The current column count.
 * @param orientation - Whether navigation is row-bounded as a grid.
 * @param wrap - Whether to wrap within the current row.
 * @param isNavigable - Whether the cursor may land on a candidate.
 * @returns The landing index or the edge that blocked the step.
 */
export function step<T>(
  index: number,
  delta: 1 | -1,
  cells: T[],
  columns: number,
  orientation: Orientation,
  wrap: boolean,
  isNavigable: (item: T) => boolean
): StepOutcome {
  const last = cells.length - 1;
  if (index < 0) {
    const seed = scan(cells, delta > 0 ? 0 : last, delta, 0, last, isNavigable);
    return seed == null
      ? { kind: "group-edge" }
      : { kind: "move", index: seed };
  }

  const rowBound = orientation === "grid" && columns > 1;
  const rowStart = rowBound ? index - (index % columns) : 0;
  // Close a ragged last row on its real end rather than on a phantom column.
  const rowEnd = rowBound ? Math.min(rowStart + columns - 1, last) : last;
  const next = scan(cells, index + delta, delta, rowStart, rowEnd, isNavigable);
  if (next != null) {
    return { kind: "move", index: next };
  }
  if (wrap) {
    const wrapped = scan(
      cells,
      delta > 0 ? rowStart : rowEnd,
      delta,
      rowStart,
      rowEnd,
      isNavigable
    );
    if (wrapped != null) {
      // Returning to the cursor is not a move, but wrap must still suppress a boundary report.
      return wrapped === index
        ? { kind: "row-edge" }
        : { kind: "move", index: wrapped };
    }
  }
  const atGroupEdge = delta > 0 ? rowEnd === last : rowStart === 0;
  return { kind: atGroupEdge ? "group-edge" : "row-edge" };
}

/**
 * Steps along the column axis, with a trailing-cell fallback for a ragged final row.
 *
 * @param index - The cursor position; the caller seeds an end before invoking this path.
 * @param direction - `1` for down or `-1` for up.
 * @param cells - The coordinate space to move through.
 * @param columns - The current column count.
 * @param wrap - Whether to wrap within the current column.
 * @param isNavigable - Whether the cursor may land on a candidate.
 * @returns The landing index or the edge that blocked the step.
 */
export function stepRow<T>(
  index: number,
  direction: 1 | -1,
  cells: T[],
  columns: number,
  wrap: boolean,
  isNavigable: (item: T) => boolean
): StepOutcome {
  const last = cells.length - 1;
  const next = scan(
    cells,
    index + direction * columns,
    direction * columns,
    0,
    last,
    isNavigable
  );
  if (next != null) {
    return { kind: "move", index: next };
  }

  // A missing column in a shorter final row falls back to that row's last navigable cell; a
  // present but non-navigable cell remains a true column edge rather than causing diagonal travel.
  const lastRowStart = last - (last % columns);
  if (
    direction > 0 &&
    Math.floor(index / columns) < Math.floor(last / columns) &&
    index + columns > last
  ) {
    const trailing = scan(cells, last, -1, lastRowStart, last, isNavigable);
    if (trailing != null) {
      return { kind: "move", index: trailing };
    }
  }
  if (wrap) {
    // Wrap to the far end of the same column, not by flat list modulo.
    const column = index % columns;
    const from =
      direction > 0
        ? column
        : column + Math.floor((last - column) / columns) * columns;
    const wrapped = scan(
      cells,
      from,
      direction * columns,
      0,
      last,
      isNavigable
    );
    if (wrapped != null) {
      // Returning to the cursor suppresses the edge without reporting a move.
      return wrapped === index
        ? { kind: "row-edge" }
        : { kind: "move", index: wrapped };
    }
  }
  return { kind: "group-edge" };
}
