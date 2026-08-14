import type { DRovingFocusConfig } from "./config";
import ItemScope from "./item-scope";
import { scan, step, type StepOutcome, stepRow } from "./navigation";
import type { DRovingFocusAxis, DRovingFocusStepResult } from "./types";

export interface ApiNavigationContext {
  config: DRovingFocusConfig;
  scope: ItemScope;
  current(items: HTMLElement[]): HTMLElement | null;
  activate(item: HTMLElement): void;
  columnCount(): number;
}

export function apiStep(
  axis: DRovingFocusAxis | undefined,
  delta: 1 | -1,
  context: ApiNavigationContext
): DRovingFocusStepResult {
  if (context.config.orientation !== "grid") {
    return stepLinear(delta, context);
  }
  const cells = context.scope.cells();
  if (!cells.some((cell) => context.scope.isNavigable(cell))) {
    return "unavailable";
  }
  const currentElement = context.current(cells);
  const current = currentElement ? cells.indexOf(currentElement) : -1;
  const resolvedAxis = axis ?? "vertical";
  const outcome = applyStep(
    resolvedAxis,
    delta,
    cells,
    current,
    context.columnCount(),
    context
  );
  return outcome.kind === "move" ? "moved" : "edge";
}

function stepLinear(
  delta: 1 | -1,
  context: ApiNavigationContext
): DRovingFocusStepResult {
  const items = context.scope.all();
  const last = items.length - 1;
  const current = context.current(items);
  const from = current ? items.indexOf(current) : -1;
  if (from < 0) {
    const seed = scan(items, delta > 0 ? 0 : last, delta, 0, last, (item) =>
      context.scope.isNavigable(item)
    );
    if (seed == null) {
      return "unavailable";
    }
    context.activate(items[seed]);
    return "moved";
  }
  const next = scan(items, from + delta, delta, 0, last, (item) =>
    context.scope.isNavigable(item)
  );
  if (next == null) {
    return "edge";
  }
  context.activate(items[next]);
  return "moved";
}

function applyStep(
  axis: DRovingFocusAxis,
  delta: 1 | -1,
  cells: HTMLElement[],
  current: number,
  columns: number,
  context: ApiNavigationContext
): StepOutcome {
  const outcome =
    axis === "horizontal" || current < 0
      ? step(
          current,
          delta,
          cells,
          columns,
          context.config.orientation,
          context.config.wrap,
          (cell) => context.scope.isNavigable(cell)
        )
      : stepRow(current, delta, cells, columns, context.config.wrap, (cell) =>
          context.scope.isNavigable(cell)
        );
  if (outcome.kind === "move") {
    context.activate(cells[outcome.index]);
  }
  return outcome;
}
