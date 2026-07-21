import {
  isDestroyed,
  isDestroying,
  registerDestructor,
} from "@ember/destroyable";
import type Owner from "@ember/owner";
import { cancel, schedule } from "@ember/runloop";
import Modifier, { type ArgsFor } from "ember-modifier";
import type { DVirtualListApi } from "discourse/ui-kit/d-virtual-list";
import {
  createElementVirtualizer,
  stableKeyFor,
  updateElementVirtualizer,
} from "discourse/ui-kit/lib/virtualizer";

type VirtualKey = number | string | bigint;

interface VisibleRange {
  startIndex: number;
  endIndex: number;
}

interface VirtualItem {
  key: VirtualKey;
  index: number;
  start: number;
  end: number;
  size: number;
  lane: number;
}

interface PublishedState {
  virtualItems: VirtualItem[];
  totalSize: number;
  range: VisibleRange | null;
}

interface StateSignature {
  totalSize: number;
  startIndex: number | undefined;
  endIndex: number | undefined;
  virtualItems: Array<
    readonly [VirtualKey, number, number, number, number, number]
  >;
}

interface VirtualizerOptions {
  anchorTo: "start" | "end";
  count: number;
  getScrollElement: () => HTMLDivElement | null;
  estimateSize: (index: number) => number;
  getItemKey: (index: number) => VirtualKey;
  overscan: number;
  onChange: () => void;
}

interface VirtualizerApi {
  range: VisibleRange | null;
  isScrolling: boolean;
  _didMount(): () => void;
  _willUpdate(): void;
  getTotalSize(): number;
  getVirtualItems(): VirtualItem[];
  measure(): void;
  measureElement(element: HTMLElement | null): void;
  scrollToIndex(
    index: number,
    options?: Parameters<DVirtualListApi["scrollToIndex"]>[1]
  ): void;
  scrollToOffset(
    offset: number,
    options?: Parameters<DVirtualListApi["scrollToOffset"]>[1]
  ): void;
  setOptions(options: VirtualizerOptions): void;
}

interface DVirtualizerSignature<T> {
  Element: HTMLDivElement;
  Args: {
    Named: {
      /** The complete list whose visible window is rendered. */
      items: readonly T[];

      /** Returns the estimated pixel size of an unmeasured item. */
      estimateSize: (item: T, index: number) => number;

      /** The number of extra items rendered outside the visible range. */
      overscan?: number;

      /** The edge where the list initially rests. */
      anchor?: "top" | "bottom";

      /** Receives newly published virtualizer state. */
      onState?: (state: PublishedState) => void;

      /** Receives the imperative virtual-list API after initialization. */
      onRegisterApi?: (api: DVirtualListApi) => void;

      /** Runs when the visible item range changes. */
      onVisibleRangeChange?: (range: VisibleRange) => void;
    };
    Positional: [];
  };
}

/**
 * Bridges the windowing engine to Glimmer's reactivity.
 *
 * Applied to the scroll element by `DVirtualList`. It owns the imperative
 * virtualizer instance and is the single reactive site for it:
 *
 * - `modify()` re-runs whenever its tracked named args change. On the first run
 *   it constructs and mounts the virtualizer; on later runs it calls
 *   `setOptions`.
 * - Engine changes enqueue one `schedule("afterRender")` flush. The flush only
 *   publishes when the total, range, or any virtual item field changes, avoiding
 *   the render loop caused by assigning an equivalent fresh array to tracked
 *   state.
 * - Teardown calls the cleanup returned by `_didMount()` and cancels any pending
 *   flush; every path that could write is fenced by destruction state.
 */
export default class DVirtualizer<T> extends Modifier<
  DVirtualizerSignature<T>
> {
  #cleanup: (() => void) | null = null;
  #element: HTMLDivElement | null = null;
  #flushScheduled = false;
  #flushTimer: ReturnType<typeof schedule> | null = null;
  #lastSignature: StateSignature | null = null;
  #named: DVirtualizerSignature<T>["Args"]["Named"] | null = null;
  #virtualizer: VirtualizerApi | null = null;

  constructor(owner: Owner, args: ArgsFor<DVirtualizerSignature<T>>) {
    super(owner, args);
    registerDestructor(this, () => this.#teardown());
  }

  modify(
    element: HTMLDivElement,
    _positional: [],
    named: DVirtualizerSignature<T>["Args"]["Named"]
  ) {
    this.#element = element;
    this.#named = named;

    const options = this.#buildOptions(
      named.items,
      named.estimateSize,
      named.overscan
    );

    if (!this.#virtualizer) {
      // The JavaScript adapter's public type loses its element and option types.
      this.#virtualizer = createElementVirtualizer(
        options
      ) as unknown as VirtualizerApi;
      this.#cleanup = this.#virtualizer._didMount();
      this.#virtualizer._willUpdate();
      named.onRegisterApi?.(this.#buildApi());
    } else {
      updateElementVirtualizer(this.#virtualizer, options);
      this.#virtualizer._willUpdate();
    }

    this.#scheduleFlush();
  }

  #buildApi(): DVirtualListApi {
    const isScrolling = () => this.#virtualizer?.isScrolling ?? false;

    return {
      scrollToIndex: (index, options) =>
        this.#virtualizer?.scrollToIndex(index, options),
      scrollToOffset: (offset, options) =>
        this.#virtualizer?.scrollToOffset(offset, options),
      scrollToEdge: (edge) => {
        const count = this.#named?.items.length ?? 0;
        if (!count) {
          return;
        }
        this.#virtualizer?.scrollToIndex(edge === "end" ? count - 1 : 0, {
          align: edge === "end" ? "end" : "start",
        });
      },
      measure: () => this.#virtualizer?.measure(),
      measureElement: (element) => this.#virtualizer?.measureElement(element),
      visibleRange: () => this.#virtualizer?.range ?? undefined,
      get isScrolling() {
        return isScrolling();
      },
    };
  }

  #buildOptions(
    items: readonly T[],
    estimateSize: (item: T, index: number) => number,
    overscan?: number
  ): VirtualizerOptions {
    return {
      // Despite the name, this does NOT set where the list rests — resting
      // position comes from `initialOffset`. The engine consults `anchorTo` in
      // exactly two places: the gate on key-based prepend anchoring, and the
      // "was at the end" branch of a row resize. We always want the former,
      // because inserting older rows above the viewport otherwise shifts
      // everything the reader is looking at by the height of what arrived.
      // The latter only engages within `scrollEndThreshold` of the true bottom.
      anchorTo: "end",
      count: items.length,
      getScrollElement: () => this.#element,
      estimateSize: (index) => estimateSize(items[index]!, index),
      getItemKey: (index) => stableKeyFor(items[index]),
      overscan: overscan ?? 5,
      onChange: () => this.#scheduleFlush(),
    };
  }

  #flush() {
    this.#flushScheduled = false;
    if (!this.#virtualizer || isDestroying(this) || isDestroyed(this)) {
      return;
    }

    // Sweep disconnected rows out of the engine's ResizeObserver. ResizeObserver
    // does not fire on removal, and the engine only self-heals opportunistically,
    // so without this the element cache grows with every row ever scrolled past.
    // NOTE: not covered by a test — see the sweep note in the PR description.
    this.#virtualizer.measureElement(null);

    const virtualItems = this.#virtualizer.getVirtualItems();
    const totalSize = this.#virtualizer.getTotalSize();
    const range = this.#virtualizer.range;
    const signature = this.#stateSignature(virtualItems, totalSize, range);

    if (this.#signaturesMatch(signature, this.#lastSignature)) {
      return;
    }
    this.#lastSignature = signature;

    this.#named?.onState?.({ virtualItems, totalSize, range });
    if (range) {
      this.#named?.onVisibleRangeChange?.(range);
    }
  }

  #scheduleFlush() {
    if (this.#flushScheduled || isDestroying(this) || isDestroyed(this)) {
      return;
    }
    this.#flushScheduled = true;
    this.#flushTimer = schedule("afterRender", this, this.#flush);
  }

  #signaturesMatch(
    current: StateSignature,
    previous: StateSignature | null
  ): boolean {
    if (
      !previous ||
      current.totalSize !== previous.totalSize ||
      current.startIndex !== previous.startIndex ||
      current.endIndex !== previous.endIndex ||
      current.virtualItems.length !== previous.virtualItems.length
    ) {
      return false;
    }

    return current.virtualItems.every((item, index) =>
      item.every(
        (value, field) => value === previous.virtualItems[index]![field]
      )
    );
  }

  #stateSignature(
    virtualItems: VirtualItem[],
    totalSize: number,
    range: VisibleRange | null
  ): StateSignature {
    return {
      totalSize,
      startIndex: range?.startIndex,
      endIndex: range?.endIndex,
      virtualItems: virtualItems.map(
        ({ key, index, start, end, size, lane }) => [
          key,
          index,
          start,
          end,
          size,
          lane,
        ]
      ),
    };
  }

  #teardown() {
    if (this.#flushTimer) {
      cancel(this.#flushTimer);
    }
    this.#flushScheduled = false;
    this.#cleanup?.();
    this.#cleanup = null;
    this.#virtualizer = null;
  }
}
