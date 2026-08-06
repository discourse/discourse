import {
  defaultRangeExtractor,
  elementScroll,
  measureElement,
  observeElementOffset,
  observeElementRect,
  Virtualizer,
} from "@tanstack/virtual-core";

/**
 * The library wall around `@tanstack/virtual-core`.
 *
 * This is the ONLY module in the app that imports the windowing engine. Plugins,
 * themes, and other core code go through `DVirtualList` and this module, never the
 * package directly, so the engine stays swappable behind the wall.
 *
 * The dependency is pinned to an EXACT version in `package.json` (no caret): the
 * adapter relies on `_didMount()`/`_willUpdate()`, which are part of the engine's
 * framework-adapter surface and can shift between minor releases. Gate any upgrade
 * on the ui-kit virtualizer test suite.
 *
 * The pin carries more weight than it looks. This module reaches the engine through
 * an unchecked cast, and the repo does not compile with strict null checks, so a
 * renamed internal or a changed virtual-item shape would type-check clean and fail
 * only at runtime. The suite is the only thing standing behind an upgrade.
 */

let VIRTUALIZATION_ENABLED = true;

/**
 * Test hook: render every item instead of a window. A `setupRenderingTest`
 * container has no real scroll/layout height, so the virtualizer would compute an
 * empty window and rows would never render. Toggling this off makes `DVirtualList`
 * yield all items in normal flow. Mirrors `disableLoadMoreObserver()`.
 *
 * `tests/setup-tests.js` disables virtualization for EVERY test and re-enables it
 * in teardown, so the render-all fallback is the default a test sees. A test that
 * needs the real engine opts in with {@link enableVirtualization}.
 *
 * Opting out is opting out of coverage: the fallback is a genuinely different code
 * path, in which the row index and the item can never disagree. Any consumer whose
 * behaviour depends on windowing needs its own companion module that opts back in,
 * or its suite proves nothing about what ships.
 *
 * The flag is read at render time and is not reactive, so it must be set before the
 * first render of a `DVirtualList`; flipping it afterwards does not re-render one
 * that already mounted.
 */
export function disableVirtualization() {
  VIRTUALIZATION_ENABLED = false;
}

/** Restore real windowing after {@link disableVirtualization}. */
export function enableVirtualization() {
  VIRTUALIZATION_ENABLED = true;
}

/**
 * Whether rows are windowed. False means the render-all fallback is active.
 *
 * @returns {boolean}
 */
export function isVirtualizationEnabled() {
  return VIRTUALIZATION_ENABLED;
}

const STABLE_KEYS = new WeakMap();

/**
 * Keys for symbol items. A strong map, unlike the object one, so a symbol used as
 * an item is retained for the life of the tab. Acceptable because symbols are
 * sentinel values a consumer defines a fixed number of, not per-row data — but it
 * is the one entry here that does not release.
 */
const STABLE_SYMBOL_KEYS = new Map();

const KEY_NAMESPACE = "d-virtual-list:key:";
let stableKeyCounter = 0;

/**
 * An immutable per-object identity key for virtual rows — the DEFAULT keying,
 * used when a consumer does not pass a `@key` field.
 *
 * By default we do NOT key on a domain id: a consumer can mutate an item's id in
 * place (e.g. an optimistic row created with a temporary id, then reconciled to a
 * server id on confirmation), which would orphan the row's measured height and
 * snap it back to its estimate. Object identity is stable across such a mutation.
 *
 * A consumer whose ids are immutable AND who rebuilds its item objects each render
 * (so object identity is NOT stable) should instead pass `@key` — see {@link keyFor}.
 *
 * @param {unknown} item
 * @returns {number | string | bigint}
 */
export function stableKeyFor(item) {
  const type = typeof item;

  if (type === "string") {
    return item.startsWith(KEY_NAMESPACE) ? `${KEY_NAMESPACE}${item}` : item;
  }

  if (type === "number" || type === "bigint") {
    return item;
  }

  if (type === "boolean" || item === null || type === "undefined") {
    return `${KEY_NAMESPACE}${type}:${String(item)}`;
  }

  if (type === "symbol") {
    let key = STABLE_SYMBOL_KEYS.get(item);
    if (key === undefined) {
      key = `${KEY_NAMESPACE}symbol:${++stableKeyCounter}`;
      STABLE_SYMBOL_KEYS.set(item, key);
    }
    return key;
  }

  let key = STABLE_KEYS.get(item);
  if (key === undefined) {
    key = `${KEY_NAMESPACE}object:${++stableKeyCounter}`;
    STABLE_KEYS.set(item, key);
  }
  return key;
}

/**
 * The row key for an item, given an optional `@key` FIELD NAME. Field values are
 * routed through {@link stableKeyFor} so a domain value inherits its namespace
 * escaping and can never collide with a generated object key.
 *
 * The field value must be UNIQUE per logical row: two rows sharing one value
 * alias to one key (a duplicate `{{#each}}` key and shared measurement), exactly
 * as two `===` items would. A row whose field is ABSENT is not treated that way —
 * it falls back to identity keying, because otherwise every such row would
 * collapse onto the single key that a nullish value normalizes to, which is a
 * collision the consumer never asked for and cannot see.
 *
 * The single source of truth for both keying paths (the modifier's `getItemKey`
 * and the component's render-all fallback), so the two can never drift.
 *
 * @param {unknown} item
 * @param {string} [field]
 * @returns {number | string | bigint}
 */
export function keyFor(item, field) {
  if (field != null && item != null && typeof item === "object") {
    const value = item[field];
    return value == null ? stableKeyFor(item) : stableKeyFor(value);
  }
  return stableKeyFor(item);
}

/**
 * The engine's viewport-rect callbacks, keyed by engine.
 *
 * The engine reads its viewport once as it mounts and then only from a ResizeObserver, whose
 * delivery is the browser's to schedule. A consumer that changes the viewport's size itself —
 * an overlay being positioned, say — knows the recorded rect is stale immediately, and holding
 * the callback lets it say so. `measure()` is not that lever: it clears the item-size cache and
 * never re-reads the viewport.
 */
const RECT_CALLBACKS = new WeakMap();

function observeElementRectWithHandle(instance, callback) {
  RECT_CALLBACKS.set(instance, callback);
  return observeElementRect(instance, callback);
}

/**
 * The engine's scroll-offset callbacks, keyed by engine.
 *
 * Held for the same reason as the viewport callbacks: the engine learns the
 * offset only from a real `scroll` event, which the browser delivers
 * asynchronously even for a programmatic scroll. Holding the callback lets a
 * caller state the new offset directly instead of counterfeiting a DOM event —
 * which would reach the engine flagged as user scrolling and latch its
 * `isScrolling` for the reset delay, suppressing synchronous row measurement
 * for that whole window.
 */
const OFFSET_CALLBACKS = new WeakMap();

function observeElementOffsetWithHandle(instance, callback) {
  OFFSET_CALLBACKS.set(instance, callback);
  return observeElementOffset(instance, callback);
}

/**
 * Tell the engine the viewport's current scroll offset, without pretending a
 * user scrolled. A no-op before the engine has mounted or once it has torn down.
 *
 * @param {{ scrollElement?: HTMLElement | null }} virtualizer
 */
export function pushScrollOffset(virtualizer) {
  const callback = OFFSET_CALLBACKS.get(virtualizer);
  const element = virtualizer?.scrollElement;

  if (!callback || !element) {
    return;
  }

  callback(element.scrollTop, false);
}

/**
 * Re-reads the viewport and pushes the measurement into the engine, which republishes its
 * window from it. A no-op before the engine has mounted or once it has torn down.
 *
 * Measured the way the engine measures it — `offsetWidth`/`offsetHeight`, rounded — so a
 * pushed rect and an observed one are the same value and cannot disagree.
 *
 * @param {{ scrollElement?: HTMLElement | null }} virtualizer
 */
export function remeasureViewport(virtualizer) {
  const callback = RECT_CALLBACKS.get(virtualizer);
  const element = virtualizer?.scrollElement;

  if (!callback || !element) {
    return;
  }

  callback({
    width: Math.round(element.offsetWidth),
    height: Math.round(element.offsetHeight),
  });
}

/**
 * The element-adapter plumbing every element-backed virtualizer needs.
 * `scrollToFn` and the two element observers are required with no engine
 * default, and `setOptions` replaces the whole options object rather than
 * merging into the previous one — so they must be re-supplied on every update,
 * not just at construction. Dropping them leaves the engine unable to scroll
 * (`scrollToFn is not a function`) the moment anything asks it to move, which
 * includes prepend anchoring and every `scrollTo*` API call.
 */
const ELEMENT_ADAPTER = {
  scrollToFn: elementScroll,
  observeElementRect: observeElementRectWithHandle,
  observeElementOffset: observeElementOffsetWithHandle,
  measureElement,
};

/**
 * A `rangeExtractor` extended with consumer-selected, otherwise-out-of-window
 * indices.
 *
 * Full-set deduplication is unconditional at this library wall because the engine
 * publishes one measurement per index with zero deduplication of its own. A
 * surviving duplicate becomes a duplicate `{{#each}}` key and a hard Glimmer
 * assertion.
 *
 * Ascending order is load-bearing, not cosmetic: `DVirtualList` positions rows by
 * absolute `translateY`, so appended extras would paint in the visually correct
 * spot while leaving the DOM sequence non-monotonic. DOM order === visual order;
 * `aria-posinset` order, screen-reader browse order, and the roving-focus NodeList
 * all depend on it.
 *
 * The callback is contained here because this is the one consumer callback the
 * engine invokes from inside its own memoized computation. Letting it throw
 * would leave that memo holding committed dependencies with no result, so every
 * later call short-circuits to `undefined` and the render crashes on it from
 * then on. Degrading to the unextended window keeps the list alive instead.
 *
 * Recovery is NOT automatic: the degraded result is a successful one as far as
 * the engine is concerned, so it is cached against the extractor identity and
 * the range. A callback that merely stops throwing is not consulted again until
 * one of those changes — which, for a consumer following the documented
 * reactivity contract, happens on the next input change.
 *
 * @param {(indices: readonly number[], range: { startIndex: number, endIndex: number, overscan: number, count: number }) => readonly number[] | null | undefined} pins Returns extra indices to keep mounted.
 * @returns {(range: { startIndex: number, endIndex: number, overscan: number, count: number }) => number[]}
 */
export function rangeExtractorWithPins(pins) {
  return (range) => {
    const indices = defaultRangeExtractor(range);
    const merged = new Set(indices);

    let extra;
    try {
      extra = pins(indices, range) ?? [];
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error("[d-virtual-list] pinnedIndices threw: ", e);
      extra = [];
    }

    for (const index of extra) {
      if (Number.isInteger(index) && index >= 0 && index < range.count) {
        merged.add(index);
      }
    }

    return [...merged].sort((a, b) => a - b);
  };
}

/**
 * Construct an element-backed virtualizer. Callers supply `count`,
 * `getScrollElement`, `estimateSize`, `getItemKey`, `overscan`, and `onChange`;
 * the element-observer plumbing is filled in here.
 *
 * @param {object} options
 * @returns {object} An element-backed virtualizer instance.
 */
export function createElementVirtualizer(options) {
  return new Virtualizer({ ...ELEMENT_ADAPTER, ...options });
}

/**
 * Re-sync options on an existing element virtualizer, preserving the adapter
 * plumbing. Always use this instead of calling `setOptions` directly.
 *
 * Typed structurally rather than as the engine's own class: callers hold their
 * own narrow view of the instance, and naming the engine type here would leak it
 * back across the wall this module exists to be.
 *
 * @param {{ setOptions: (options: object) => void }} virtualizer
 * @param {object} options
 */
export function updateElementVirtualizer(virtualizer, options) {
  virtualizer.setOptions({ ...ELEMENT_ADAPTER, ...options });
}
