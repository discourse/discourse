import type {
  DRovingFocusApi,
  DRovingFocusAxis,
  DRovingFocusStepResult,
} from "./types";

/** Internal operations used to bind the stable public cursor API to its owner. */
export interface RovingFocusApiPort {
  items(): HTMLElement[];
  currentItem(): HTMLElement | null;
  activate(item: HTMLElement): void;
  clear(): boolean;
  step(
    axis: DRovingFocusAxis | undefined,
    delta: 1 | -1
  ): DRovingFocusStepResult;
  reannounce(): boolean;
}

/** Creates an immutable cursor API backed by the supplied strategy port. */
export function createRovingFocusApi(
  port: RovingFocusApiPort
): DRovingFocusApi {
  const api: DRovingFocusApi = {
    focusFirst: () => {
      const items = port.items();
      if (!items.length) {
        return false;
      }
      port.activate(items[0]);
      return true;
    },
    focusLast: () => {
      const items = port.items();
      if (!items.length) {
        return false;
      }
      port.activate(items[items.length - 1]);
      return true;
    },
    focusIndex: (index) => {
      const items = port.items();
      if (!items.length || !Number.isInteger(index)) {
        return false;
      }
      const last = items.length - 1;
      port.activate(items[Math.max(0, Math.min(index, last))]);
      return true;
    },
    focusLogicalIndex: (index) => {
      const items = port.items();
      if (!items.length || !Number.isFinite(index)) {
        return false;
      }
      const match = items.find((item) => {
        const stamp = item.dataset.logicalIndex ?? item.dataset.index;
        return stamp !== undefined && Number(stamp) === index;
      });
      if (match) {
        port.activate(match);
        return true;
      }
      const positional = items.every(
        (item) =>
          item.dataset.logicalIndex === undefined &&
          item.dataset.index === undefined
      );
      // Stamped lookup accepts any finite numeric match, but positional lookup indexes an array.
      if (
        !positional ||
        !Number.isInteger(index) ||
        index < 0 ||
        index >= items.length
      ) {
        return false;
      }
      port.activate(items[index]);
      return true;
    },
    clear: () => port.clear(),
    focusNext: (axis) => port.step(axis, 1),
    focusPrevious: (axis) => port.step(axis, -1),
    items: () => port.items(),
    currentItem: () => port.currentItem(),
    indexOf: (item) => port.items().indexOf(item),
    focusElement: (item) => {
      if (!port.items().includes(item)) {
        return false;
      }
      port.activate(item);
      return true;
    },
    reannounceActive: () => port.reannounce(),
  };
  return Object.freeze(api);
}
