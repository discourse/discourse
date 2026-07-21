import {
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
 * An immutable per-object identity key for virtual rows.
 *
 * NEVER key virtual rows on a domain id. A consumer can mutate an item's id in
 * place (e.g. an optimistic row created with a temporary id, then reconciled to a
 * server id on confirmation). Keying on that id would orphan the row's measured
 * height at the moment of mutation and snap the row back to its estimate. Object
 * identity is stable across such a mutation, so it is what we key on.
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
const ELEMENT_ADAPTER = {
  scrollToFn: elementScroll,
  observeElementRect,
  observeElementOffset,
  measureElement,
};

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
