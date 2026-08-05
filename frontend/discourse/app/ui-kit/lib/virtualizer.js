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
 * adapter relies on `_didMount()`/`_willUpdate()`, which are part of virtual-core's
 * framework-adapter surface and can shift between minor releases. Gate any upgrade
 * on the ui-kit virtualizer test suite.
 */

let VIRTUALIZATION_ENABLED = true;

/**
 * Test hook: render every item instead of a window. A `setupRenderingTest`
 * container has no real scroll/layout height, so the virtualizer would compute an
 * empty window and rows would never render. Toggling this off makes `DVirtualList`
 * yield all items in normal flow. Mirrors `disableLoadMoreObserver()`.
 *
 * Tests that disable virtualization must re-enable it in teardown, mirroring the
 * explicit load-more observer setup/teardown in `tests/setup-tests.js`.
 */
export function disableVirtualization() {
  VIRTUALIZATION_ENABLED = false;
}

export function enableVirtualization() {
  VIRTUALIZATION_ENABLED = true;
}

export function isVirtualizationEnabled() {
  return VIRTUALIZATION_ENABLED;
}

const STABLE_KEYS = new WeakMap();
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
 * Ordinary string, number, and bigint items act as their own keys. Other
 * primitives are normalized into a reserved namespace, and strings beginning
 * with that namespace are escaped so they cannot collide with generated keys.
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
 * The row key for an item, given an optional `@key` FIELD NAME. When `field` is
 * set and the row is a non-null object, the row keys by `item[field]` (routed
 * through {@link stableKeyFor}, so a domain value inherits the same namespace
 * escaping and can never collide with a generated object key). Otherwise — no
 * field, or a nullish/primitive row — it falls back to identity keying, so every
 * item shape `stableKeyFor` already supports keeps working.
 *
 * The field value must be PRESENT and UNIQUE per logical row: two rows with a
 * missing/duplicate field value alias to one key (a duplicate `{{#each}}` key and
 * shared measurement), exactly as two `===` items would.
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
    return stableKeyFor(item[field]);
  }
  return stableKeyFor(item);
}

/**
 * Construct a virtual-core `Virtualizer` wired for a scrollable DOM element.
 * Callers supply `count`, `getScrollElement`, `estimateSize`, `getItemKey`,
 * `overscan`, and `onChange`; the element-observer plumbing is filled in here.
 *
 * @param {object} options
 * @returns {Virtualizer}
 */
/**
 * The element-adapter plumbing every element-backed virtualizer needs. These are
 * required options with no defaults, and `setOptions` replaces the whole options
 * object rather than merging into the previous one — so they must be re-supplied
 * on every update, not just at construction. Dropping them leaves the engine
 * unable to scroll (`scrollToFn is not a function`) the moment anything asks it
 * to move, which includes prepend anchoring and every `scrollTo*` API call.
 */
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

const ELEMENT_ADAPTER = {
  scrollToFn: elementScroll,
  observeElementRect: observeElementRectWithHandle,
  observeElementOffset,
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
 * @param {(indices: readonly number[], range: { startIndex: number, endIndex: number, overscan: number, count: number }) => readonly number[] | null | undefined} pins Returns extra indices to keep mounted.
 * @returns {(range: { startIndex: number, endIndex: number, overscan: number, count: number }) => number[]}
 */
export function rangeExtractorWithPins(pins) {
  return (range) => {
    const indices = defaultRangeExtractor(range);
    const merged = new Set(indices);

    for (const index of pins(indices, range) ?? []) {
      if (Number.isInteger(index) && index >= 0 && index < range.count) {
        merged.add(index);
      }
    }

    return [...merged].sort((a, b) => a - b);
  };
}

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
