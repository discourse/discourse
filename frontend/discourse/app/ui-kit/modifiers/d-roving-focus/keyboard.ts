import type { DRovingFocusConfig } from "./config";
import type RovingFocusDiagnostics from "./diagnostics";
import type ItemScope from "./item-scope";
import { scan, step, type StepOutcome, stepRow } from "./navigation";
import TypeAhead from "./type-ahead";
import type { DRovingFocusApi, DRovingFocusAxis } from "./types";

/**
 * Input types with no text caret, so an arrow key means navigation there rather than a cursor
 * move the field owns.
 */
const NON_ARROW_INPUT_TYPES = new Set([
  "button",
  "checkbox",
  "file",
  "image",
  "reset",
  "submit",
]);

/** Operations and state needed to route one keypress. */
export interface KeyboardContext {
  config: DRovingFocusConfig;
  scope: ItemScope;
  controller: HTMLElement | null;
  api: DRovingFocusApi;
  diagnostics: RovingFocusDiagnostics;
  current(items: HTMLElement[]): HTMLElement | null;
  columnCount(): number;
  activate(item: HTMLElement): void;
}

/** Routes owned keyboard commands to navigation, activation, or type-ahead. */
export default class KeyboardRouter {
  #typeAhead = new TypeAhead();

  /** Applies the type-ahead portion of the latest configuration. */
  configure(config: DRovingFocusConfig): void {
    this.#typeAhead.configure(config.typeAhead);
  }

  /** Routes a keydown while leaving unowned keys unconsumed. */
  handle(event: KeyboardEvent, context: KeyboardContext): void {
    const { config, scope } = context;
    if (event.isComposing) {
      return;
    }
    if (
      config.focusStrategy === "roving-tabindex" &&
      this.#isEditable(event.target)
    ) {
      return;
    }
    // Type-ahead must run before the active-mode allow-list and chord guard: printable keys are
    // absent from the allow-list, and Shift is how a capital letter arrives.
    if (
      config.typeAhead &&
      this.#typeAhead.handle(event, {
        editableController:
          config.focusStrategy === "active-descendant" &&
          this.#isEditable(context.controller),
        logicalCount: config.logicalCount,
        mountedCount: () => scope.all().length,
        items: () => scope.items(),
        currentIndex: (items) => this.#currentIndex(items, context),
        activate: context.activate,
        reannounce: () => void context.api.reannounceActive(),
        warnWindowed: () => context.diagnostics.warnWindowedTypeAhead(),
      })
    ) {
      return;
    }
    // Active mode owns Home and End only when the controller has no text caret to move.
    if (
      config.focusStrategy === "active-descendant" &&
      event.key !== "ArrowDown" &&
      event.key !== "ArrowUp" &&
      event.key !== "Enter" &&
      event.key !== "PageUp" &&
      event.key !== "PageDown" &&
      !(
        (event.key === "Home" || event.key === "End") &&
        !this.#isEditable(context.controller)
      )
    ) {
      return;
    }
    if (event.ctrlKey || event.metaKey || event.altKey || event.shiftKey) {
      return;
    }

    const cells = scope.cells();
    if (!cells.length) {
      return;
    }
    const current = this.#currentIndex(cells, context);
    const columns = context.columnCount();
    const last = cells.length - 1;
    const horizontal =
      config.orientation === "horizontal" || config.orientation === "grid";
    const vertical =
      config.focusStrategy === "active-descendant" ||
      config.orientation === "vertical" ||
      config.orientation === "grid";
    const key = this.#logicalKey(event.key, scope.container);

    let outcome: StepOutcome;
    switch (key) {
      case "ArrowRight":
      case "ArrowLeft": {
        if (!horizontal) {
          this.#emitCrossAxis(
            key === "ArrowRight" ? "forward" : "backward",
            cells,
            current,
            event,
            config
          );
          return;
        }
        const delta = key === "ArrowRight" ? 1 : -1;
        outcome = this.#applyStep(
          "horizontal",
          delta,
          cells,
          current,
          columns,
          context
        );
        if (outcome.kind === "group-edge") {
          this.#emitBoundary(delta, "horizontal", current, event, config);
          return;
        }
        break;
      }
      case "ArrowDown":
      case "ArrowUp": {
        if (!vertical) {
          this.#emitCrossAxis(
            key === "ArrowDown" ? "forward" : "backward",
            cells,
            current,
            event,
            config
          );
          return;
        }
        const direction = key === "ArrowDown" ? 1 : -1;
        outcome = this.#applyStep(
          "vertical",
          direction,
          cells,
          current,
          columns,
          context
        );
        if (outcome.kind === "group-edge") {
          this.#emitBoundary(direction, "vertical", current, event, config);
          return;
        }
        break;
      }
      case "Home":
        if (config.logicalCount != null) {
          this.#jump(0, "backward", event, context);
          return;
        }
        outcome = this.#applyOutcome(
          this.#edgeOutcome(cells, 0, 1, last, scope),
          cells,
          context
        );
        break;
      case "End":
        if (config.logicalCount != null) {
          this.#jump(config.logicalCount - 1, "forward", event, context);
          return;
        }
        outcome = this.#applyOutcome(
          this.#edgeOutcome(cells, last, -1, last, scope),
          cells,
          context
        );
        break;
      case "PageUp":
      case "PageDown": {
        if (config.logicalCount == null) {
          return;
        }
        const forward = key === "PageDown";
        // With no cursor, anchor on the mounted window; calculating from -1 would page backward.
        const anchor =
          current >= 0
            ? current
            : scan(
                cells,
                forward ? 0 : last,
                forward ? 1 : -1,
                0,
                last,
                (cell) => scope.isNavigable(cell)
              );
        const logical = this.#logicalIndex(cells, anchor ?? 0);
        // A placeholder-only window has no navigable items, but a zero-sized page would stall.
        const page = Math.max(1, scope.items().length);
        this.#jump(
          forward
            ? Math.min(logical + page, config.logicalCount - 1)
            : Math.max(logical - page, 0),
          forward ? "forward" : "backward",
          event,
          context
        );
        return;
      }
      case "Enter":
      case " ":
        // These guards are independent: containment can resolve a nested control as the current
        // item, while disabled cells remain in the coordinate space to preserve grid arithmetic.
        if (
          current >= 0 &&
          config.onActivate &&
          scope.isActivatable(cells[current]) &&
          (config.focusStrategy === "active-descendant" ||
            event.target === cells[current])
        ) {
          event.preventDefault();
          config.onActivate(cells[current], event);
        }
        return;
      default:
        return;
    }

    if (outcome.kind === "move" || outcome.kind === "row-edge") {
      event.preventDefault();
    }
  }

  /** Releases type-ahead resources. */
  destroy(): void {
    this.#typeAhead.destroy();
  }

  #currentIndex(items: HTMLElement[], context: KeyboardContext): number {
    const current = context.current(items);
    return current ? items.indexOf(current) : -1;
  }

  /**
   * Runs one step and commits a landing. Travels the row axis whenever there is no cursor yet,
   * because the column walk has no anchor to count from.
   */
  #applyStep(
    axis: DRovingFocusAxis,
    delta: 1 | -1,
    cells: HTMLElement[],
    current: number,
    columns: number,
    context: KeyboardContext
  ): StepOutcome {
    const { config, scope } = context;
    const outcome =
      axis === "horizontal" || current < 0
        ? step(
            current,
            delta,
            cells,
            columns,
            config.orientation,
            config.wrap,
            (cell) => scope.isNavigable(cell)
          )
        : stepRow(current, delta, cells, columns, config.wrap, (cell) =>
            scope.isNavigable(cell)
          );
    return this.#applyOutcome(outcome, cells, context);
  }

  #applyOutcome(
    outcome: StepOutcome,
    cells: HTMLElement[],
    context: KeyboardContext
  ): StepOutcome {
    if (outcome.kind === "move") {
      context.activate(cells[outcome.index]);
    }
    return outcome;
  }

  #edgeOutcome(
    cells: HTMLElement[],
    from: number,
    delta: number,
    last: number,
    scope: ItemScope
  ): StepOutcome {
    const index = scan(cells, from, delta, 0, last, (cell) =>
      scope.isNavigable(cell)
    );
    return index == null ? { kind: "group-edge" } : { kind: "move", index };
  }

  #emitBoundary(
    delta: number,
    axis: DRovingFocusAxis,
    current: number,
    event: KeyboardEvent,
    config: DRovingFocusConfig
  ): void {
    if (current >= 0 && config.onBoundary) {
      event.preventDefault();
      config.onBoundary(delta > 0 ? "forward" : "backward", axis);
    }
  }

  #emitCrossAxis(
    direction: "forward" | "backward",
    cells: HTMLElement[],
    current: number,
    event: KeyboardEvent,
    config: DRovingFocusConfig
  ): void {
    if (
      current >= 0 &&
      config.onCrossAxis?.(direction, cells[current], event)
    ) {
      event.preventDefault();
    }
  }

  /**
   * Moves to an absolute logical index, handing off to the consumer when that row is not mounted.
   * The key is left un-prevented when neither can service it, so it stays a dead key nowhere.
   */
  #jump(
    target: number,
    direction: "forward" | "backward",
    event: KeyboardEvent,
    context: KeyboardContext
  ): void {
    if (context.api.focusLogicalIndex(target)) {
      event.preventDefault();
    } else if (context.config.onJump) {
      event.preventDefault();
      context.config.onJump(target, direction);
    }
  }

  /**
   * The absolute index a mounted row stands for, falling back to its position when the consumer
   * stamps neither attribute, which is what a non-windowed group looks like.
   */
  #logicalIndex(cells: HTMLElement[], current: number): number {
    const element = cells[current];
    const value = element?.dataset.logicalIndex ?? element?.dataset.index;
    if (value === undefined) {
      return current;
    }
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : current;
  }

  /**
   * Mirrors the horizontal arrows under a right-to-left container, so every path downstream reads
   * a key as the direction a reader means by it rather than as a physical side.
   */
  #logicalKey(key: string, container: HTMLElement): string {
    if (getComputedStyle(container).direction !== "rtl") {
      return key;
    }
    if (key === "ArrowLeft") {
      return "ArrowRight";
    }
    return key === "ArrowRight" ? "ArrowLeft" : key;
  }

  /** Whether a target owns a text caret, and so owns the keys that move one. */
  #isEditable(target: EventTarget | null): boolean {
    if (!(target instanceof HTMLElement)) {
      return false;
    }
    const tag = target.tagName;
    if (tag === "TEXTAREA" || tag === "SELECT" || target.isContentEditable) {
      return true;
    }
    return (
      tag === "INPUT" &&
      !NON_ARROW_INPUT_TYPES.has((target as HTMLInputElement).type)
    );
  }
}
