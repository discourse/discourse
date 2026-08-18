import {
  isDestroyed,
  isDestroying,
  registerDestructor,
} from "@ember/destroyable";
import type Owner from "@ember/owner";
import { cancel, schedule } from "@ember/runloop";
import Modifier, { type ArgsFor } from "ember-modifier";
import { prefersReducedMotion } from "discourse/lib/utilities";
import type { DVirtualListApi } from "discourse/ui-kit/d-virtual-list";
import {
  createElementVirtualizer,
  isVirtualizationEnabled,
  keyFor,
  pushScrollOffset,
  rangeExtractorWithPins,
  remeasureViewport,
  updateElementVirtualizer,
} from "discourse/ui-kit/lib/virtualizer";

type VirtualKey = number | string | bigint;

/**
 * How close (in rows) the visible range must come to an edge before its reach
 * callback arms. A few rows of lead time lets a fetch land before the reader
 * reaches the true edge.
 */
const DEFAULT_EDGE_THRESHOLD = 8;

/**
 * Once an edge has fired, the range must retreat this many rows PAST the band
 * before the edge re-arms. Without the gap, a range hovering on the band
 * boundary would re-fire on every jitter.
 */
const EDGE_HYSTERESIS = 4;

/**
 * The engine's own tolerance for treating a computed offset and the element's
 * snapped `scrollTop` as the same position. Its offsets come from arithmetic over
 * estimates and alignment halving, while `scrollTop` is snapped to the browser's
 * layout grid, so exact equality is the wrong comparison and would leave the two
 * permanently "disagreeing" for a fractional row size.
 */
const SCROLL_EPSILON = 1.5;

interface VisibleRange {
  startIndex: number;
  endIndex: number;
}

interface VirtualRange extends VisibleRange {
  overscan: number;
  count: number;
}

type PinnedIndices = (
  indices: readonly number[],
  range: VirtualRange
) => readonly number[];

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
  /**
   * The rendered window. Frozen, and a copy of the engine's own array rather than
   * the array itself, so a consumer cannot write into the memoized result the
   * engine hands back on every later read. Only the array is frozen: the items in
   * it are reconstructed per computation, so a write to one cannot outlive the
   * next window change.
   */
  virtualItems: readonly VirtualItem[];
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
  followOnAppend: boolean;
  scrollEndThreshold?: number;
  rangeExtractor?: (range: VirtualRange) => number[];
}

interface VirtualizerApi {
  range: VisibleRange | null;
  isScrolling: boolean;
  /** The viewport the engine measures and scrolls. Null until it mounts. */
  scrollElement: HTMLElement | null;

  /**
   * The engine's cached scroll offset (px). Null until the first measure. The
   * element's real `scrollTop` is the source of truth; this can drift from it
   * when the browser clamps a scroll the engine never observed.
   */
  scrollOffset: number | null;
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

      /**
       * The edge the list rests at. `"bottom"` additionally makes the engine
       * follow appends while the reader is within `scrollEndThreshold` of the
       * end; the initial rest position is applied by the component, not here.
       */
      anchor?: "top" | "bottom";

      /**
       * Distance from the end, in px, that still counts as "at the end". Governs
       * both the follow-on-append gate and the engine's at-end row-resize branch.
       * Defaults to the engine's own value, which is 1px.
       */
      scrollEndThreshold?: number;

      /**
       * Extends the default window with extra absolute indices to keep mounted.
       * Invalid and duplicate extras are discarded, and the result stays in
       * ascending index order. See {@link rangeExtractorWithPins}.
       */
      pinnedIndices?: PinnedIndices;

      /** Receives newly published virtualizer state. */
      onState?: (state: PublishedState) => void;

      /**
       * Receives the imperative virtual-list API after initialization.
       *
       * Delivered synchronously during the first `modify()`, unlike the other
       * callbacks here, which are delivered from the after-render flush. The
       * phase is load-bearing: a consumer that positions the list and then calls
       * back into the API needs the handle before that positioning runs. The
       * cost is that writing tracked state already consumed in this render pass
       * will trip a backtracking assertion — do that work in a later phase.
       */
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

  /**
   * The start latch begins satisfied (mount at the top is not a "reached start"
   * event); the end latch begins unsatisfied so a list whose first page already
   * fills to the end fires its end callback on mount. `count === 0` resets both.
   */
  #startLatched = true;
  #endLatched = false;

  /**
   * True while an edge callback is running. `armEdge` is inert then: the callback
   * would be clearing the latch this evaluation has just set, and the flush it
   * schedules would fire the same callback again, with no yield in between.
   */
  #inEdgeCallback = false;

  /**
   * The edge keys the latches were last evaluated against. A latch can only be
   * re-armed by a range retreat, which an `@items` change never produces: rows
   * arriving beyond the viewport move the BAND, not the range. Watching the keys
   * instead re-arms the edge the change actually touched. Null until the first
   * non-empty evaluation seeds them, which is what keeps mount suppression
   * intact across the initial transition from zero to a populated list.
   */
  #lastFirstKey: VirtualKey | null = null;
  #lastLastKey: VirtualKey | null = null;

  /**
   * The item count the edges were last evaluated against. A latch may only be
   * re-armed by a list that actually changed length, so that an in-place refresh
   * cannot be mistaken for rows arriving at an edge.
   */
  #lastCount = 0;

  /** Reentrancy guard for the synchronous offset push (see `#syncScrollOffset`). */
  #syncingScroll = false;

  /**
   * Snapshotted from the named arg in `modify()` (not read live at flush time)
   * so that CHANGING it re-invokes `modify()` — which schedules a flush that
   * re-arms the latches against the new band. Reading it only inside `#flush`
   * would leave a threshold change without a flush, so the latches would never
   * re-arm until the next unrelated scroll.
   */
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

    this.#edgeThreshold = named.edgeThreshold ?? DEFAULT_EDGE_THRESHOLD;

    const options = this.#buildOptions(named);

    if (!this.#virtualizer) {
      // Build into locals and only adopt once mounting has fully succeeded.
      //
      // `_willUpdate()` is not inert on a first run: it attaches the observers,
      // and the rect observer reports eagerly, which measures every index through
      // the consumer's `estimateSize`. If that throws mid-way while `#virtualizer`
      // is already assigned, every later `modify()` takes the update branch and
      // the API is never registered — so `measureRow` stays a no-op and NO row is
      // ever measured, silently, for the life of the list.
      //
      // TODO(devxp-typescript-pending): Remove once the JavaScript adapter
      // preserves the engine's element and option types.
      const virtualizer = createElementVirtualizer(
        options
      ) as unknown as VirtualizerApi;

      let cleanup: (() => void) | null = null;
      try {
        cleanup = virtualizer._didMount();
        virtualizer._willUpdate();
      } catch (e) {
        cleanup?.();
        throw e;
      }

      this.#virtualizer = virtualizer;
      this.#cleanup = cleanup;
      named.onRegisterApi?.(this.#buildApi());
    } else {
      updateElementVirtualizer(this.#virtualizer, options);
      this.#growSizerToTotal();
      this.#virtualizer._willUpdate();
      this.#resyncScrollOffset();
    }

    this.#scheduleFlush();
  }

  /** The element whose height stands in for the whole list. */
  #sizer() {
    return (
      this.#element?.querySelector<HTMLElement>(
        ":scope > .d-virtual-list__sizer"
      ) ?? null
    );
  }

  /**
   * Sets the sizer to the engine's current total, so the scrollbar spans the whole
   * list while only a window is mounted.
   *
   * This modifier is the ONLY writer of that height. Sharing it with the component
   * would not merely be untidy: Glimmer installs a parent's modifier update before
   * its children's, so a height the component derived from tracked state would land
   * after this one and carry the PREVIOUS flush's total — reverting the raise below
   * within the same commit, and leaving the engine to reconcile a scroll target it
   * captured against a height that no longer exists.
   *
   * An empty list gets no height at all: the `empty` block renders inside this
   * element, and a self-centering empty state would collapse into a zero-height box.
   *
   * @param options - `grow` raises the height but never lowers it.
   */
  #applySizerHeight({ grow = false } = {}) {
    const sizer = this.#sizer();
    if (!sizer || !this.#virtualizer) {
      return;
    }

    if (!(this.#named?.items.length ?? 0)) {
      sizer.style.removeProperty("height");
      return;
    }

    const total = this.#virtualizer.getTotalSize();
    if (grow && total <= sizer.offsetHeight) {
      return;
    }

    sizer.style.height = `${total}px`;
  }

  /**
   * Raise the sizer to the engine's new total BEFORE the engine acts on the options
   * it was just given.
   *
   * `setOptions` resolves the keyed scroll anchor and stashes it; `_willUpdate` then
   * writes that offset to the element. At this instant the element is still as tall
   * as the OLD list, and the browser clamps a scroll past the end of it — so a
   * prepend larger than the reader's remaining distance to the bottom lands short,
   * losing the very anchor that exists to hold their position.
   *
   * Raise only. Lowering here would clamp in the other direction while the engine
   * is still deciding where to go; the flush sets the exact height afterwards.
   */
  #growSizerToTotal() {
    this.#applySizerHeight({ grow: true });
  }

  /**
   * After an `@items` change the engine can hold a scroll offset the element no
   * longer has: shrinking the sizer makes the browser clamp `scrollTop`, but that
   * clamp does not reach the engine's offset observer, so it keeps computing the
   * window from a stale, now out-of-range offset. On its own that only mis-scrolls
   * the window; combined with pinned indices it surfaces as a visible gap — the
   * pinned row renders at its true offset while the window sits far below it, and
   * the rows between are absent. Adopt the element's real `scrollTop` whenever the
   * two disagree so the window tracks the actual position.
   *
   * Compared with a tolerance rather than exactly, because the engine's offset is
   * arithmetic over estimates while `scrollTop` is snapped to the layout grid. A
   * no-op when they already agree, which is the common case now that
   * `#growSizerToTotal` keeps a grown list's anchored scroll reachable.
   */
  #resyncScrollOffset() {
    const element = this.#element;
    if (
      this.#syncingScroll ||
      !element?.isConnected ||
      isDestroying(this) ||
      isDestroyed(this)
    ) {
      return;
    }
    const engineOffset = this.#virtualizer?.scrollOffset ?? null;
    if (
      engineOffset === null ||
      Math.abs(engineOffset - element.scrollTop) < SCROLL_EPSILON
    ) {
      return;
    }

    // Only correct an offset that is genuinely out of range. A mere disagreement
    // is normal mid-update — the engine may have just issued a programmatic scroll
    // whose target it has not observed yet — and adopting the element's position
    // there would overwrite that intent and settle the window somewhere stale.
    //
    // Measured against the ENGINE's new total rather than the element's height,
    // which may still describe the outgoing list during the update-time call.
    // The flush calls again after settling the height so a shrink's forced layout
    // exposes the browser-clamped position before the window is read.
    const maxOffset = Math.max(
      this.#virtualizer.getTotalSize() - element.clientHeight,
      0
    );
    if (engineOffset <= maxOffset + SCROLL_EPSILON) {
      return;
    }

    this.#syncingScroll = true;
    try {
      pushScrollOffset(this.#virtualizer);
    } finally {
      this.#syncingScroll = false;
    }
  }

  /**
   * Strip an animated scroll when the reader has asked for reduced motion, so a
   * consumer does not have to check for it at every call site.
   *
   * @param options - The caller's scroll options.
   * @returns The options, with any animation removed if motion is unwelcome.
   */
  #respectMotionPreference<O extends { behavior?: ScrollBehavior }>(
    options: O | undefined
  ): O | undefined {
    if (options?.behavior === "smooth" && prefersReducedMotion()) {
      return { ...options, behavior: "auto" };
    }
    return options;
  }

  #buildApi(): DVirtualListApi {
    const isScrolling = () => this.#virtualizer?.isScrolling ?? false;

    return {
      scrollToIndex: (index, options) => {
        const before = this.#element?.scrollTop;
        this.#virtualizer?.scrollToIndex(
          index,
          this.#respectMotionPreference(options)
        );
        this.#syncScrollOffset(before);
      },
      scrollToOffset: (offset, options) => {
        const before = this.#element?.scrollTop;
        this.#virtualizer?.scrollToOffset(
          offset,
          this.#respectMotionPreference(options)
        );
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
      armEdge: (edge) => {
        if (
          !this.#virtualizer ||
          this.#inEdgeCallback ||
          isDestroying(this) ||
          isDestroyed(this)
        ) {
          return;
        }
        if (edge === "end") {
          this.#endLatched = false;
        } else {
          this.#startLatched = false;
        }
        // Clearing the latch is all this does. The callback fires from the next
        // flush's edge evaluation, and only if the range is still in the band, so
        // a consumer cannot drive its own callback by calling this.
        this.#scheduleFlush();
      },
      measure: () => this.#virtualizer?.measure(),
      remeasureViewport: () => {
        if (this.#virtualizer) {
          remeasureViewport(this.#virtualizer);
        }
      },
      measureElement: (element) => {
        // The engine resolves the row from the `data-index` that `place` stamps. Given
        // anything it cannot resolve it warns, then observes the element under a key no
        // row has, for the life of the list. Refuse it here rather than poison the cache.
        // Checked against the item count rather than just parsed, because an index past
        // the end resolves to no row just as surely as a missing one.
        if (!(element instanceof HTMLElement)) {
          return;
        }
        // Read the raw attribute first: `Number("")` is 0, so an empty `data-index`
        // would otherwise pass as a valid index into the first row.
        const raw = element.dataset.index;
        if (raw === undefined || raw.trim() === "") {
          return;
        }
        const index = Number(raw);
        if (
          !Number.isInteger(index) ||
          index < 0 ||
          index >= (this.#named?.items.length ?? 0)
        ) {
          return;
        }
        this.#virtualizer?.measureElement(element);
      },
      visibleRange: () =>
        this.#freezeRange(this.#virtualizer?.range ?? null) ?? undefined,
      get isScrolling() {
        return isScrolling();
      },
    };
  }

  /**
   * The engine reads the scroll offset only from the element's `scroll` event,
   * which `element.scrollTo` (used by every programmatic scroll) fires
   * ASYNCHRONOUSLY. Left to that, the window would not reflect an imperative
   * scroll until a later tick — imperceptible in a browser, but a race that
   * leaves a rendering test unsettled at the old window. Pushing the offset
   * straight into the engine makes a programmatic scroll immediately consistent;
   * the real async event that follows is a no-op (the engine short-circuits when
   * the offset already matches).
   *
   * Guarded so it only pushes when the scroll actually moved, never on a
   * detached/destroyed element, and never re-enters.
   *
   * A `behavior: "smooth"` scroll does not move `scrollTop` synchronously, so it
   * takes the no-op branch and settles through the engine's own reconcile loop
   * instead.
   *
   * @param previousScrollTop - The offset before the scroll was requested.
   */
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
      pushScrollOffset(this.#virtualizer);
    } finally {
      this.#syncingScroll = false;
    }
  }

  #buildOptions(
    named: DVirtualizerSignature<T>["Args"]["Named"]
  ): VirtualizerOptions {
    const { items, estimateSize, overscan, key, pinnedIndices } = named;
    // Fractional and non-finite ranges can permanently poison engine memoization;
    // negative ranges leave viewport gaps.
    const normalizedOverscan =
      overscan === undefined || !Number.isFinite(overscan)
        ? 5
        : Math.max(0, Math.floor(overscan));

    const options: VirtualizerOptions = {
      // Despite the name, this does NOT set where the list rests — the component
      // applies the initial position. Unconditional because it gates key-based
      // prepend anchoring, which we always want: inserting older rows above the
      // viewport otherwise shifts everything the reader is looking at by the
      // height of what arrived. The engine's other uses of it are additionally
      // bounded by `scrollEndThreshold`.
      anchorTo: "end",
      count: items.length,
      getScrollElement: () => this.#element,
      estimateSize: (index) => estimateSize(items[index]!, index),
      getItemKey: (index) => keyFor(items[index], key),
      overscan: normalizedOverscan,
      onChange: () => this.#scheduleFlush(),
      // Only a bottom-anchored list tracks the live edge. The engine gates this
      // on the reader having been within `scrollEndThreshold` of the end BEFORE
      // the append, so a reader who has scrolled up to read history is never
      // yanked down by arriving rows.
      followOnAppend: named.anchor === "bottom",
    };

    // Left unset the engine keeps its own 1px default. `setOptions` skips
    // undefined values, so passing it through unconditionally would be harmless
    // but would misrepresent "unset" as an explicit choice.
    if (named.scrollEndThreshold != null) {
      options.scrollEndThreshold = named.scrollEndThreshold;
    }

    // Set the extractor only when there is something to pin, so the engine keeps
    // its own default path when there isn't — and so dropping `@pinnedIndices`
    // reverts cleanly rather than installing a pass-through.
    if (pinnedIndices != null) {
      options.rangeExtractor = rangeExtractorWithPins(pinnedIndices);
    }

    return options;
  }

  #flush() {
    this.#flushScheduled = false;
    if (!this.#virtualizer || isDestroying(this) || isDestroyed(this)) {
      return;
    }

    // Sweep disconnected rows out of the engine's ResizeObserver. A ResizeObserver
    // does not fire on removal, and the engine only self-heals opportunistically,
    // so without this the element cache grows with every row ever scrolled past.
    // The sweep contract is pinned in the virtualizer unit suite.
    this.#virtualizer.measureElement(null);

    // Settle a shrink before reading the window. Reading `scrollTop` during the
    // resync forces the browser to apply the height clamp, and pushes that
    // position into the engine before anything can be published.
    this.#applySizerHeight();
    this.#resyncScrollOffset();

    const virtualItems = this.#virtualizer.getVirtualItems();
    const totalSize = this.#virtualizer.getTotalSize();
    const range = this.#virtualizer.range;
    const count = this.#named?.items.length ?? 0;

    const signature = this.#stateSignature(virtualItems, totalSize, range);

    // Hand out frozen copies, never the engine's own objects. `range` stays
    // attached to the engine between computations and its committed value is what
    // the engine's change memo compares against, and `getVirtualItems()` returns a
    // memoized array the engine keeps handing back — so a consumer that wrote
    // through either could silently stop the window from updating.
    const publishedRange = this.#freezeRange(range);
    const publishedItems = Object.freeze([...virtualItems]);

    // Publish BEFORE any edge callback runs. The window is what the component
    // needs to render at all, so it must not sit behind a consumer callback that
    // could throw — the engine's own change memo has already committed by the
    // time this runs, so a flush lost to an exception is never re-driven and the
    // list would stay blank for good.
    if (!this.#signaturesMatch(signature, this.#lastSignature)) {
      this.#lastSignature = signature;

      const published = this.#safely("onState", () =>
        this.#named?.onState?.({
          virtualItems: publishedItems,
          totalSize,
          range: publishedRange,
        })
      );

      // Drop the memo when the publish did not happen. Unlike the edge callbacks,
      // this one carries the window the component renders from, so remembering a
      // publish that threw would match forever and strand the list on whatever it
      // last drew — for a mounted list nobody scrolls, that is permanent.
      if (!published) {
        this.#lastSignature = null;
      }

      // A row remeasurement changes the signature (sizes/offsets shift) without
      // moving the visible indices. Gate the range callback on a real start/end
      // change so a size-only remeasure does not publish a spurious range event.
      if (range && this.#rangeIndicesChanged(range)) {
        this.#lastEmittedRange = {
          startIndex: range.startIndex,
          endIndex: range.endIndex,
        };
        this.#safely("onVisibleRangeChange", () =>
          this.#named?.onVisibleRangeChange?.(publishedRange!)
        );
      }
    }

    // Deliberately outside the signature gate: the edge inputs (range, count,
    // threshold) are not all captured by the rendering signature, so a
    // threshold-only change — which leaves the rendered window identical — must
    // still re-arm the latches.
    this.#evaluateEdges(range, count);
  }

  /**
   * Runs a callback so that throwing cannot abort the flush around it.
   *
   * A latch or cache the caller owns is committed BEFORE the call, so a callback
   * that throws every time is not retried on every subsequent flush. That trade
   * only makes sense for a callback whose loss costs the consumer an event; where
   * the loss would instead desync the rendered window, the caller must undo its
   * commit on a false return rather than memoize a publish that never happened.
   *
   * @param label - Callback name, used to attribute the error.
   * @param run - The callback to invoke.
   * @returns Whether it completed without throwing.
   */
  #safely(label: string, run: () => void): boolean {
    try {
      run();
      return true;
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(`[d-virtual-list] ${label} threw: `, e);
      return false;
    }
  }

  /**
   * Re-arms the edge whose boundary row changed identity, so a consumer that
   * answers an edge callback by growing the list can reach that edge again.
   *
   * Direction matters: an append moves the end band away from a range that has
   * not moved, so the retreat rule alone would re-arm only for a page bigger than
   * the band plus hysteresis, and a smaller page would stall the edge forever.
   * Keying off the boundary rows instead re-arms exactly the edge that gained
   * rows, which is why a tail change must not disturb the start latch.
   *
   * @param count - The total number of items, known to be non-zero.
   */
  #rearmEdgesForItemChange(count: number) {
    const named = this.#named;
    if (!named) {
      return;
    }

    const firstKey = keyFor(named.items[0], named.key);
    const lastKey = keyFor(named.items[count - 1], named.key);
    const previousCount = this.#lastCount;

    this.#lastCount = count;

    // Seed only: the first non-empty evaluation must not unlatch, or a list that
    // mounts non-empty would lose the deliberate start-edge suppression.
    if (this.#lastFirstKey === null && this.#lastLastKey === null) {
      this.#lastFirstKey = firstKey;
      this.#lastLastKey = lastKey;
      return;
    }

    const previousFirstKey = this.#lastFirstKey;
    const previousLastKey = this.#lastLastKey;
    this.#lastFirstKey = firstKey;
    this.#lastLastKey = lastKey;

    // Whether a changed boundary key means anything depends on how rows are keyed.
    //
    // With an explicit `@key` the key IS the row's logical identity, so a changed
    // boundary is a genuinely different row and re-arming is right even at a
    // constant length — which is exactly a capped stream, appending at the tail
    // while dropping from the head.
    //
    // Without one, rows key by object identity, and a consumer that rebuilds its
    // items in place hands over brand new boundary keys for the very same rows.
    // Re-arming there would answer an edge callback with an edge callback: the
    // consumer refreshes, the boundary key changes, the range is still in the
    // band, and it fires again. So an unkeyed list additionally has to have
    // changed length before a boundary is believed.
    if (!named.key && count === previousCount) {
      return;
    }

    const headChanged = firstKey !== previousFirstKey;
    const tailChanged = lastKey !== previousLastKey;

    if (!headChanged && !tailChanged && count === previousCount) {
      return;
    }

    // Neither boundary moved yet the list changed length, so rows were inserted
    // between them — which is what a list carrying a stable trailing sentinel
    // looks like, a loading skeleton or placeholder that outlives the page it
    // announces. The side cannot be told apart, so arm both rather than let an
    // edge stall forever behind a row whose key never changes.
    if (!headChanged && !tailChanged) {
      this.#startLatched = false;
      this.#endLatched = false;
      return;
    }

    if (headChanged) {
      this.#startLatched = false;
    }
    if (tailChanged) {
      this.#endLatched = false;
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

  /**
   * Fires `onReachStart`/`onReachEnd` once per entry into an edge band, re-arming
   * after the range retreats past the band plus hysteresis OR when the list gains
   * a new edge (see `#rearmEdgesForItemChange`). An empty list resets both
   * latches so a refill re-fires; a null range holds the current state (nothing
   * measured yet) but still tracks the edges.
   *
   * @param range - The visible range, or null before anything has been measured.
   * @param count - The total number of items.
   */
  #evaluateEdges(range: VisibleRange | null, count: number) {
    if (count === 0) {
      this.#startLatched = true;
      this.#endLatched = false;
      // Dropping the emitted range alongside the latches keeps an empty->refill
      // cycle from swallowing the new list's first range event when it happens to
      // land on the same indices.
      this.#lastEmittedRange = null;
      this.#lastFirstKey = null;
      this.#lastLastKey = null;
      this.#lastCount = 0;
      return;
    }

    this.#rearmEdgesForItemChange(count);

    if (!range) {
      return;
    }

    const threshold = this.#edgeThreshold;
    const startBand = threshold;
    const endBand = count - 1 - threshold;

    if (range.startIndex <= startBand) {
      if (!this.#startLatched) {
        this.#startLatched = true;
        this.#inEdgeCallback = true;
        try {
          this.#safely("onReachStart", () =>
            this.#named?.onReachStart?.({ ...range, count })
          );
        } finally {
          this.#inEdgeCallback = false;
        }
      }
    } else if (range.startIndex > startBand + EDGE_HYSTERESIS) {
      this.#startLatched = false;
    }

    if (range.endIndex >= endBand) {
      if (!this.#endLatched) {
        this.#endLatched = true;
        this.#inEdgeCallback = true;
        try {
          this.#safely("onReachEnd", () =>
            this.#named?.onReachEnd?.({ ...range, count })
          );
        } finally {
          this.#inEdgeCallback = false;
        }
      }
    } else if (range.endIndex < endBand - EDGE_HYSTERESIS) {
      this.#endLatched = false;
    }
  }

  /**
   * A frozen copy of a range. Hand these out, never the engine's own object: `range`
   * stays attached to the engine between computations, and its committed value is what
   * the engine's change memo compares against.
   */
  #freezeRange(range: VisibleRange | null): Readonly<VisibleRange> | null {
    return range
      ? Object.freeze({
          startIndex: range.startIndex,
          endIndex: range.endIndex,
        })
      : null;
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
    // Drop the publish and edge bookkeeping with the engine that produced it.
    // This path is not only destruction: the disabled-virtualization branch tears
    // down a live modifier, and a later re-enable builds a FRESH engine that must
    // not inherit the previous one's de-dup memo or latch state.
    this.#lastSignature = null;
    this.#lastEmittedRange = null;
    this.#lastFirstKey = null;
    this.#lastLastKey = null;
    this.#lastCount = 0;
    this.#startLatched = true;
    this.#endLatched = false;
    // Drop the element too: a retained API handle or a pending `next()` scroll
    // must not dispatch a synthetic event onto a detached node after teardown.
    this.#element = null;
  }
}
