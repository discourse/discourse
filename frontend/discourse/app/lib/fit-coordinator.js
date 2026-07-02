// @ts-check
import { schedule } from "@ember/runloop";

/**
 * Coordinates width-driven "fit" decisions for many elements through ONE shared
 * `ResizeObserver` and a single batched measure pass.
 *
 * A "fit" consumer is anything that must react to how much width an element has:
 * an action bar that folds its buttons into an overflow menu as it narrows, a
 * control that swaps a wide layout for a compact one, a responsive strip that
 * changes how many items it shows. Each consumer registers a target with three
 * pure-ish pieces of behavior:
 *
 *   - `measure(observedEl)` — READS whatever it needs (sub-element widths, an
 *     item count, …) and returns opaque data. It MUST NOT write to the DOM: it
 *     runs inside the shared read phase, and a write here would force a reflow
 *     mid-batch and defeat the batching.
 *   - `decide(availWidth, data)` — a PURE function mapping the available width
 *     plus the measured data to a decision (typically a short string from a
 *     closed set, e.g. `"full" | "compact"`).
 *   - `apply` — how a CHANGED decision is written: either an attribute name the
 *     coordinator sets on the target element (so a stylesheet can key off it) or
 *     a callback the coordinator invokes with the new decision (so JS/reactive
 *     state can switch on it).
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
 */

/** @typedef {"attribute"} FitApplyAttributeKind */

/**
 * @typedef {object} FitTarget
 * @property {any} key - Stable identity for the registration (usually the target
 *   element). Re-registering the same key replaces the descriptor and re-measures.
 * @property {HTMLElement} observedEl - Element whose width the observer watches
 *   and whose `clientWidth` is passed to `decide` as the available width. Its
 *   width should be independent of the applied decision (otherwise the
 *   apply→resize→measure cycle can oscillate).
 * @property {(observedEl: HTMLElement) => any} measure - Read phase; returns data
 *   for `decide`. Must not write to the DOM.
 * @property {(availWidth: number, data: any) => any} decide - Pure decision.
 * @property {{ attribute: string, targetEl?: HTMLElement } | { callback: (decision: any) => void }} apply
 *   - How a changed decision is written. With `attribute`, the coordinator sets
 *   that attribute on `targetEl` (defaulting to `observedEl`). With `callback`,
 *   the coordinator invokes it with the new decision.
 * @property {(a: any, b: any) => boolean} [equals] - Optional equality used to
 *   diff the previous and next decision; defaults to `Object.is`.
 */

/**
 * @typedef {object} FitRecord
 * @property {HTMLElement} observedEl
 * @property {(observedEl: HTMLElement) => any} measure
 * @property {(availWidth: number, data: any) => any} decide
 * @property {FitTarget["apply"]} apply
 * @property {(a: any, b: any) => boolean} equals
 * @property {any} last - The last applied decision, or the `UNSET` sentinel
 *   before the first apply (so the first decision always applies).
 */

/**
 * Sentinel for "no decision applied yet". A dedicated object (never a value a
 * `decide` could return) so the first measure always writes, even when the first
 * decision equals some natural default.
 */
const UNSET = Symbol("fit-unset");

/** @type {ResizeObserver | null} */
let observer = null;

/** @type {(() => void) | null} The bound window-resize handler, when attached. */
let onWindowResize = null;

/** @type {Map<any, FitRecord>} Registered targets, keyed by their `key`. */
const registry = new Map();

/** Whether a measure pass is already queued for the next `afterRender`. */
let measureScheduled = false;

/**
 * Registers a target for fit coordination and computes its initial decision.
 * Idempotent by `key`: re-registering replaces the descriptor and re-measures.
 *
 * @param {FitTarget} target
 * @returns {() => void} A dispose function that unregisters this target
 *   (idempotent). It also clears an attribute-strategy target's attribute.
 */
export function registerFit(target) {
  const { key, observedEl, measure, decide, apply, equals } = target;
  if (key == null || !observedEl) {
    return () => {};
  }

  // Preserve the last applied decision across a re-registration of the same key
  // so a modifier that re-registers on every run (its normal re-measure path)
  // doesn't reset the diff and force a redundant apply.
  const existing = registry.get(key);
  registry.set(key, {
    observedEl,
    measure,
    decide,
    apply,
    equals: equals ?? Object.is,
    last: existing ? existing.last : UNSET,
  });

  ensureObserver();
  observer?.observe(observedEl);
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
 * Stops tracking a target. Idempotent: a second call is a no-op, and
 * `unobserve` on an already-unobserved element is harmless. For an
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
  observer?.unobserve(record.observedEl);

  const { apply } = record;
  if ("attribute" in apply) {
    (apply.targetEl ?? record.observedEl).removeAttribute(apply.attribute);
  }
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
  registry.clear();
  measureScheduled = false;
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
  observer = new ResizeObserver(() => scheduleMeasure());
  onWindowResize = () => scheduleMeasure();
  window.addEventListener("resize", onWindowResize);
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
 * then write-all: all measurement/decisions happen first (one layout flush for
 * the batch), then all applies — so a write never forces a reflow before the
 * next target's read. Writes are diffed so an unchanged decision touches nothing.
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
    const data = record.measure(record.observedEl);
    const decision = record.decide(record.observedEl.clientWidth, data);
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
 * on the target element, or invoke the callback.
 *
 * @param {FitRecord} record
 * @param {any} decision
 */
function applyDecision(record, decision) {
  const { apply, observedEl } = record;
  if ("attribute" in apply) {
    (apply.targetEl ?? observedEl).setAttribute(apply.attribute, decision);
  } else {
    apply.callback(decision);
  }
}
