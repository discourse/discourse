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
  isVirtualizationEnabled,
  keyFor,
  rangeExtractorWithPinned,
  updateElementVirtualizer,
} from "discourse/ui-kit/lib/virtualizer";

type VirtualKey = number | string | bigint;

// How close (in rows) the visible range must come to an edge before its reach
// callback arms. Eight rows ahead gives a fetch time to land before the reader
// hits the true edge.
const DEFAULT_EDGE_THRESHOLD = 8;

// Once an edge has fired, the range must retreat this many rows PAST the band
// before the edge re-arms. Without the gap, a range hovering on the band
// boundary would re-fire on every jitter.
const EDGE_HYSTERESIS = 4;

interface VisibleRange {
  startIndex: number;
  endIndex: number;
}

/** The visible range plus the total item count, handed to an edge callback. */
interface EdgeInfo extends VisibleRange {
  count: number;
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
  rangeExtractor?: (range: {
    startIndex: number;
    endIndex: number;
    overscan: number;
    count: number;
  }) => number[];
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

      /**
       * Field name whose value is the row's STABLE key (see {@link keyFor}). Without
       * it rows key by object identity, so a consumer that rebuilds its item objects
       * each render (fresh objects, same logical rows) orphans every measurement and
       * remounts the whole window. The field must be present and unique per row;
       * nullish/primitive rows fall back to identity keying.
       */
      key?: string;

      /** The number of extra items rendered outside the visible range. */
      overscan?: number;

      /** The edge where the list initially rests. */
      anchor?: "top" | "bottom";

      /**
       * An absolute index kept rendered even when scrolled out of the window, so
       * a keyboard-active row never unmounts (its `aria-activedescendant` id
       * cannot dangle). Merged into the window in ascending index order — see
       * {@link rangeExtractorWithPinned}.
       */
      pinnedIndex?: number;

      /** Receives newly published virtualizer state. */
      onState?: (state: PublishedState) => void;

      /** Receives the imperative virtual-list API after initialization. */
      onRegisterApi?: (api: DVirtualListApi) => void;

      /** Runs when the visible item range changes. */
      onVisibleRangeChange?: (range: VisibleRange) => void;

      /**
       * Runs once when the visible range enters the START band (within
       * `edgeThreshold` rows of index 0), re-arming only after it retreats past
       * the band plus hysteresis. Mount at the start is suppressed (the start
       * latch begins satisfied) so a list that opens at the top does not fire.
       */
      onReachStart?: (info: EdgeInfo) => void;

      /**
       * Runs once when the visible range enters the END band (within
       * `edgeThreshold` rows of the last index), re-arming after retreat past
       * hysteresis. Unlike the start edge, the end latch begins UNsatisfied, so
       * a list whose first page already reaches the end fires on mount.
       */
      onReachEnd?: (info: EdgeInfo) => void;

      /** Rows from an edge at which its reach callback arms (default 8). */
      edgeThreshold?: number;
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
  #lastEmittedRange: VisibleRange | null = null;
  #named: DVirtualizerSignature<T>["Args"]["Named"] | null = null;
  #virtualizer: VirtualizerApi | null = null;

  // The start latch begins satisfied (mount at the top is not a "reached start"
  // event); the end latch begins unsatisfied so a list whose first page already
  // fills to the end fires its end callback on mount. `count === 0` resets both.
  #startLatched = true;
  #endLatched = false;

  // Reentrancy guard for the synchronous scroll dispatch (see #syncScrollOffset).
  #syncingScroll = false;

  // Snapshotted from the named arg in `modify()` (not read live at flush time)
  // so that CHANGING it re-invokes `modify()` — which schedules a flush that
  // re-arms the latches against the new band. Reading it only inside `#flush`
  // would leave a threshold change without a flush, so the latches would never
  // re-arm until the next unrelated scroll.
  #edgeThreshold = DEFAULT_EDGE_THRESHOLD;

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

    // When virtualization is globally disabled (the test render-all fallback), the
    // modifier is fully inert: the component renders every row in normal flow, so there
    // is no window to drive. Building the engine anyway would still fire edge/range
    // callbacks off a zero-height container — e.g. trip onReachEnd on mount — driving a
    // consumer's edge fetch against a list that is fully mounted. Tear down any engine a
    // prior enabled run built, so "disabled ⇒ no live virtualizer" holds and a stale
    // engine cannot keep scheduling flushes after the flag flips (a fresh mount has none).
    if (!isVirtualizationEnabled()) {
      if (this.#virtualizer) {
        this.#teardown();
      }
      return;
    }

    // Consume the threshold here (not just at flush time) so a change to it
    // re-runs modify() and schedules the flush that re-arms the latches.
    this.#edgeThreshold = named.edgeThreshold ?? DEFAULT_EDGE_THRESHOLD;

    const options = this.#buildOptions(
      named.items,
      named.estimateSize,
      named.overscan,
      named.key,
      named.pinnedIndex
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
      scrollToIndex: (index, options) => {
        const before = this.#element?.scrollTop;
        this.#virtualizer?.scrollToIndex(index, options);
        this.#syncScrollOffset(before);
      },
      scrollToOffset: (offset, options) => {
        const before = this.#element?.scrollTop;
        this.#virtualizer?.scrollToOffset(offset, options);
        this.#syncScrollOffset(before);
      },
      scrollToEdge: (edge) => {
        const count = this.#named?.items.length ?? 0;
        if (!count) {
          return;
        }
        const before = this.#element?.scrollTop;
        this.#virtualizer?.scrollToIndex(edge === "end" ? count - 1 : 0, {
          align: edge === "end" ? "end" : "start",
        });
        this.#syncScrollOffset(before);
      },
      measure: () => this.#virtualizer?.measure(),
      measureElement: (element) => this.#virtualizer?.measureElement(element),
      visibleRange: () => this.#virtualizer?.range ?? undefined,
      get isScrolling() {
        return isScrolling();
      },
    };
  }

  // The engine reads the scroll offset only from the element's `scroll` event,
  // which `element.scrollTo` (used by every programmatic scroll) fires
  // ASYNCHRONOUSLY. Left to that, the window would not reflect an imperative
  // scroll until a later tick — imperceptible in a browser, but a race that
  // leaves a rendering test unsettled at the old window. Dispatching the event
  // synchronously makes a programmatic scroll immediately consistent; the real
  // async event that follows is a no-op (the engine short-circuits when the
  // offset already matches).
  //
  // Guarded so it only fires when the scroll actually moved (a no-op scroll must
  // not fake an `isScrolling` transition), never on a detached/destroyed element,
  // and never re-enters — a consumer `scroll` listener that calls a scroll API
  // would otherwise recurse through the synthetic dispatch.
  #syncScrollOffset(previousScrollTop: number | undefined) {
    const element = this.#element;
    if (
      this.#syncingScroll ||
      !element?.isConnected ||
      isDestroying(this) ||
      isDestroyed(this) ||
      element.scrollTop === previousScrollTop
    ) {
      return;
    }
    this.#syncingScroll = true;
    try {
      element.dispatchEvent(new Event("scroll"));
    } finally {
      this.#syncingScroll = false;
    }
  }

  #buildOptions(
    items: readonly T[],
    estimateSize: (item: T, index: number) => number,
    overscan?: number,
    key?: string,
    pinnedIndex?: number
  ): VirtualizerOptions {
    const options: VirtualizerOptions = {
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
      getItemKey: (index) => keyFor(items[index], key),
      overscan: overscan ?? 5,
      onChange: () => this.#scheduleFlush(),
    };

    // Only override the range when there is something to pin: passing an explicit
    // `rangeExtractor: undefined` through `setOptions` would replace the engine's
    // own default with undefined and crash the next measure.
    if (pinnedIndex != null) {
      options.rangeExtractor = rangeExtractorWithPinned(pinnedIndex);
    }

    return options;
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

    // Edge evaluation runs on EVERY flush, ahead of the rendering-signature
    // de-dup: its inputs (range, count, threshold) are not all captured by that
    // signature, so a threshold-only change — which leaves the rendered window
    // identical — must still re-arm the latches.
    this.#evaluateEdges(range, this.#named?.items.length ?? 0);

    const signature = this.#stateSignature(virtualItems, totalSize, range);

    if (this.#signaturesMatch(signature, this.#lastSignature)) {
      return;
    }
    this.#lastSignature = signature;

    this.#named?.onState?.({ virtualItems, totalSize, range });

    // A row remeasurement changes the signature (sizes/offsets shift) without
    // moving the visible indices. Gate the range callback on a real start/end
    // change so a size-only remeasure does not publish a spurious range event.
    if (range && this.#rangeIndicesChanged(range)) {
      this.#lastEmittedRange = {
        startIndex: range.startIndex,
        endIndex: range.endIndex,
      };
      this.#named?.onVisibleRangeChange?.(range);
    }
  }

  #rangeIndicesChanged(range: VisibleRange): boolean {
    const last = this.#lastEmittedRange;
    return (
      !last ||
      last.startIndex !== range.startIndex ||
      last.endIndex !== range.endIndex
    );
  }

  // Fires `onReachStart`/`onReachEnd` once per entry into an edge band, re-arming
  // only after the range retreats past the band plus hysteresis. An empty list
  // resets both latches so a refill re-fires; a null range holds the current
  // state (nothing measured yet).
  #evaluateEdges(range: VisibleRange | null, count: number) {
    if (count === 0) {
      this.#startLatched = true;
      this.#endLatched = false;
      return;
    }
    if (!range) {
      return;
    }

    const threshold = this.#edgeThreshold;
    const startBand = threshold;
    const endBand = count - 1 - threshold;

    if (range.startIndex <= startBand) {
      if (!this.#startLatched) {
        this.#startLatched = true;
        this.#named?.onReachStart?.({ ...range, count });
      }
    } else if (range.startIndex > startBand + EDGE_HYSTERESIS) {
      this.#startLatched = false;
    }

    if (range.endIndex >= endBand) {
      if (!this.#endLatched) {
        this.#endLatched = true;
        this.#named?.onReachEnd?.({ ...range, count });
      }
    } else if (range.endIndex < endBand - EDGE_HYSTERESIS) {
      this.#endLatched = false;
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
    // Drop the element too: a retained API handle or a pending `next()` scroll
    // must not dispatch a synthetic event onto a detached node after teardown.
    this.#element = null;
  }
}
