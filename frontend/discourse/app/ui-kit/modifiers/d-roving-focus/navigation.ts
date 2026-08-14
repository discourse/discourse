import type { Orientation } from "./types";

export type StepOutcome =
  | { kind: "move"; index: number }
  | { kind: "row-edge" }
  | { kind: "group-edge" };

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
      return wrapped === index
        ? { kind: "row-edge" }
        : { kind: "move", index: wrapped };
    }
  }
  const atGroupEdge = delta > 0 ? rowEnd === last : rowStart === 0;
  return { kind: atGroupEdge ? "group-edge" : "row-edge" };
}

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
      return wrapped === index
        ? { kind: "row-edge" }
        : { kind: "move", index: wrapped };
    }
  }
  return { kind: "group-edge" };
}
