// @ts-check
import { assert } from "@ember/debug";
import { schedule } from "@ember/runloop";

/**
 * Coordinates width-driven "fit" decisions for many elements through ONE shared
 * `ResizeObserver` and a single batched measure pass.
 *
 * A "fit" consumer is anything that must react to how much width an element has:
 * an action bar that folds its buttons into an overflow menu as it narrows, a
 * control that swaps a wide layout for a compact one, a responsive strip that
 * changes how many items it shows. Each consumer registers a target with a
 * single decision function and one write strategy:
 *
 *   - `compute(availWidth, observedEl)` — READS whatever it needs (sub-element
 *     widths, an item count, …) and returns the decision, typically a short
 *     string from a closed set (e.g. `"full" | "compact"`). It runs inside the
 *     SHARED read phase: it MUST NOT write to the DOM (no attribute, class, or
 *     style changes) — a write here forces a reflow mid-batch and defeats the
 *     batching for every registered target, not just this one.
 *   - `attribute` OR `onChange` — how a CHANGED decision is written: either an
 *     attribute name the coordinator sets on the observed element (so a
 *     stylesheet can key off it) or a callback the coordinator invokes with the
 *     new decision (so JS/reactive state can switch on it). Exactly one must be
 *     provided.
 *
 * Why one coordinator instead of an observer per consumer: a single
 * `ResizeObserver` over N targets lets every width change in a runloop coalesce
 * into ONE `afterRender` pass that reads ALL targets first and only then writes
 * ALL of them. That read-all-then-write-all discipline means a write never
 * forces a reflow before the next target's read — the layout-thrash a naive
 * "measure, write, measure, write" loop would cause. Writes are diffed against
 * the last decision, so an unchanged decision touches nothing (no attribute
 * write, no callback, no re-render), which is also what keeps a decision that
 * doesn't alter the observed width from looping back through the observer.
 *
 * This module holds a single lazily-built observer for the whole app. It has no
 * per-app teardown of its own (its lifetime is the page); tests reset it through
 * {@link resetFitCoordinator} so state never leaks across test boundaries.
 *
 * @example
 * const dispose = registerFit({
 *   key: el,
 *   observedEl: el,
 *   compute: (availWidth, observedEl) =>
 *     availWidth >= observedEl.querySelector(".labels").offsetWidth
 *       ? "full"
 *       : "compact",
 *   attribute: "data-fit", // a stylesheet keys off [data-fit="compact"]
 * });
 * // …later, after a content change that doesn't resize the observed box:
 * refreshFit(el);
 * // …on teardown:
 * dispose();
 */

/**
 * @typedef {{ attribute: string } | { onChange: (decision: any) => void }} FitStrategy
 *   How a changed decision is written: set `attribute` to the decision on the
 *   observed element (cleared on unregister), or invoke `onChange` with it.
 */

/**
 * @typedef {object} FitTarget
 * @property {any} key - Stable identity for the registration. Re-registering
 *   the same key replaces the descriptor and re-measures; when the observed
 *   element is unchanged, the last decision is preserved for diffing.
 * @property {HTMLElement} observedEl - Element whose width the observer watches
 *   and whose `clientWidth` is passed to `compute` as the available width. Its
 *   width should be independent of the applied decision (otherwise the
 *   apply→resize→measure cycle can oscillate).
 * @property {(availWidth: number, observedEl: HTMLElement) => any} compute -
 *   The decision function; runs in the shared read phase and MUST NOT write to
 *   the DOM.
 * @property {string} [attribute] - Write strategy A: the coordinator sets this
 *   attribute to each changed decision on `observedEl`, and removes it on
 *   unregister. Mutually exclusive with `onChange` — provide exactly one.
 * @property {(decision: any) => void} [onChange] - Write strategy B: invoked
 *   with each changed decision. Mutually exclusive with `attribute`.
 * @property {(a: any, b: any) => boolean} [equals] - Optional equality used to
 *   diff the previous and next decision; defaults to `Object.is`. Prefer
 *   primitive decisions so the default suffices.
 */

/**
 * @typedef {object} FitRecord
 * @property {HTMLElement} observedEl
 * @property {(availWidth: number, observedEl: HTMLElement) => any} compute
 * @property {FitStrategy} strategy
 * @property {(a: any, b: any) => boolean} equals
 * @property {any} last - The last applied decision, or the `UNSET` sentinel
 *   before the first apply (so the first decision always applies).
 */

/**
 * Sentinel for "no decision applied yet". A dedicated object (never a value a
 * `compute` could return) so the first measure always writes, even when the
 * first decision equals some natural default.
 */
const UNSET = Symbol("fit-unset");

/** @type {ResizeObserver | null} */
let observer = null;

/** @type {(() => void) | null} The bound window-resize handler, when attached. */
let onWindowResize = null;

/** @type {Map<any, FitRecord>} Registered targets, keyed by their `key`. */
const registry = new Map();

/**
 * How many registrations currently observe each element. Observation is shared:
 * the element is observed on the first registration and unobserved only when
 * the last one goes away, so registrations that share an observed element can't
 * silently disable each other.
 *
 * @type {Map<HTMLElement, number>}
 */
const observedCounts = new Map();

/** Whether a measure pass is already queued for the next `afterRender`. */
let measureScheduled = false;

/**
 * A pending animation-frame handle for an observer-triggered measure, or `null`.
 * Observer reactions are deferred by one frame (see {@link ensureObserver}), and
 * this coalesces a burst of observer callbacks into a single deferred measure.
 *
 * @type {number | null}
 */
let observerFrame = null;

/**
 * Registers a target for fit coordination and computes its initial decision.
 * Idempotent by `key`: re-registering replaces the descriptor and re-measures.
 * When the observed element changed, the old element is released (and an
 * attribute-strategy attribute cleared from it) before the new one is tracked.
 *
 * @param {FitTarget} target
 * @returns {() => void} A dispose function that unregisters this target
 *   (idempotent). It also clears an attribute-strategy target's attribute.
 */
export function registerFit(target) {
  const { key, observedEl, compute, attribute, onChange, equals } = target;
  if (key == null || !observedEl) {
    return () => {};
  }

  assert(
    "registerFit: provide exactly one of `attribute` or `onChange`",
    (attribute != null) !== (onChange != null)
  );

  // Preserve the last applied decision across a re-registration of the same key
  // so a consumer that re-registers on every re-run (its normal re-measure
  // path) doesn't reset the diff and force a redundant apply. A changed
  // observed element starts clean instead: the old element is released and
  // un-stamped, and the sentinel guarantees the new element gets a first write.
  const existing = registry.get(key);
  const sameElement = existing?.observedEl === observedEl;
  if (existing && !sameElement) {
    releaseObservedElement(existing);
  }

  const strategy =
    attribute != null
      ? { attribute }
      : { onChange: /** @type {(decision: any) => void} */ (onChange) };
  registry.set(key, {
    observedEl,
    compute,
    strategy,
    equals: equals ?? Object.is,
    last: existing && sameElement ? existing.last : UNSET,
  });

  ensureObserver();
  if (!sameElement) {
    trackObservedElement(observedEl);
  }
  scheduleMeasure();

  return () => unregisterFit(key);
}

/**
 * Re-measures a still-registered target after a content change that alters its
 * measurement without resizing the observed box (a different item set, a locale
 * switch). A plain resize is handled by the observer alone.
 *
 * @param {any} key
 */
export function refreshFit(key) {
  if (registry.has(key)) {
    scheduleMeasure();
  }
}

/**
 * Stops tracking a target. Idempotent: a second call is a no-op. For an
 * attribute-strategy target, its attribute is removed so a later re-selection
 * starts clean.
 *
 * @param {any} key
 */
export function unregisterFit(key) {
  const record = registry.get(key);
  if (!record) {
    return;
  }
  registry.delete(key);
  releaseObservedElement(record);
}

/**
 * Tears the coordinator down and clears all state. TEST-ONLY: wired into the
 * QUnit test-cleanup so the module singleton never leaks observers, listeners,
 * or registrations across tests. Not needed in production, where the
 * coordinator's lifetime is the page.
 */
export function resetFitCoordinator() {
  observer?.disconnect();
  observer = null;
  if (onWindowResize) {
    window.removeEventListener("resize", onWindowResize);
    onWindowResize = null;
  }
  if (observerFrame != null) {
    cancelAnimationFrame(observerFrame);
    observerFrame = null;
  }
  registry.clear();
  observedCounts.clear();
  measureScheduled = false;
}

/**
 * Starts observing a record's element, sharing the observation with any other
 * registration already watching it (refcounted).
 *
 * @param {HTMLElement} el
 */
function trackObservedElement(el) {
  const count = observedCounts.get(el) ?? 0;
  if (count === 0) {
    observer?.observe(el);
  }
  observedCounts.set(el, count + 1);
}

/**
 * Releases a record's observed element: drops one observation refcount
 * (unobserving only when no other registration still watches the element) and
 * clears an attribute-strategy attribute from it.
 *
 * @param {FitRecord} record
 */
function releaseObservedElement(record) {
  const { observedEl, strategy } = record;

  const count = observedCounts.get(observedEl) ?? 0;
  if (count <= 1) {
    observedCounts.delete(observedEl);
    observer?.unobserve(observedEl);
  } else {
    observedCounts.set(observedEl, count - 1);
  }

  if ("attribute" in strategy) {
    observedEl.removeAttribute(strategy.attribute);
  }
}

/**
 * Lazily builds the single shared observer plus a window-resize fallback on
 * first registration. The observer fires on per-target width changes; the
 * window listener catches reflows that change a target's width without resizing
 * the observed box directly.
 */
function ensureObserver() {
  if (observer) {
    return;
  }
  // React one animation frame after the observer fires rather than inside its
  // callback. A measure pass can change an observed element's size — a consumer
  // whose rendered content depends on the decision resizes when it swaps — and
  // mutating an observed element from within the observer's own delivery cycle
  // makes the browser end that cycle with pending notifications ("ResizeObserver
  // loop completed with undelivered notifications"). Deferring to the next frame
  // moves the mutation out of the delivery cycle, so the observer only ever sees
  // a settled size. The window-resize fallback is not inside a delivery cycle,
  // so it can schedule directly.
  observer = new ResizeObserver(scheduleMeasureFromObserver);
  onWindowResize = () => scheduleMeasure();
  window.addEventListener("resize", onWindowResize);
}

/**
 * Defers an observer-triggered measure to the next animation frame, coalescing a
 * burst of observer callbacks into one. See {@link ensureObserver} for why the
 * observer must not measure inside its own callback.
 */
function scheduleMeasureFromObserver() {
  if (observerFrame != null) {
    return;
  }
  observerFrame = requestAnimationFrame(() => {
    observerFrame = null;
    scheduleMeasure();
  });
}

/**
 * Coalesces every measure trigger in a runloop into one `afterRender` pass, so a
 * burst (multiple resizes, a multi-registration) measures once.
 */
function scheduleMeasure() {
  if (measureScheduled) {
    return;
  }
  measureScheduled = true;
  schedule("afterRender", null, measureAll);
}

/**
 * Measures every registered target and applies its decision. Strictly read-all
 * then write-all: all decisions are computed first (one layout flush for the
 * batch), then all applies — so a write never forces a reflow before the next
 * target's read. Writes are diffed so an unchanged decision touches nothing.
 */
function measureAll() {
  measureScheduled = false;

  // Read phase — pure measurement + decision, no writes.
  /** @type {Array<[FitRecord, any]>} */
  const decisions = [];
  for (const record of registry.values()) {
    if (!record.observedEl.isConnected) {
      continue;
    }
    const decision = record.compute(
      record.observedEl.clientWidth,
      record.observedEl
    );
    decisions.push([record, decision]);
  }

  // Write phase — apply only changed decisions, no measurement.
  for (const [record, decision] of decisions) {
    if (record.last !== UNSET && record.equals(record.last, decision)) {
      continue;
    }
    record.last = decision;
    applyDecision(record, decision);
  }
}

/**
 * Applies a decision through the record's configured strategy: set the attribute
 * on the observed element, or invoke the callback.
 *
 * @param {FitRecord} record
 * @param {any} decision
 */
function applyDecision(record, decision) {
  const { strategy, observedEl } = record;
  if ("attribute" in strategy) {
    observedEl.setAttribute(strategy.attribute, decision);
  } else {
    strategy.onChange(decision);
  }
}
