// @ts-check
import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { registerFit, unregisterFit } from "discourse/lib/fit-coordinator";

/**
 * A consumer's fit decision function. Given the observed element's available
 * width (and, for the rare cross-element consumer, the attached element and the
 * observed element), it returns the decision — typically a short string from a
 * closed set. The decision type is opaque to the primitive, so it is typed as
 * `any` here.
 *
 * @typedef {(availWidth: number, element: HTMLElement, observedEl: HTMLElement) => any} FitCompute
 */

/**
 * @typedef {object} DFitNamedArgs
 * @property {string} [attribute] - Write strategy A: the coordinator sets this attribute to each changed decision on the observed element.
 * @property {(decision: any) => void} [onChange] - Write strategy B: called with each changed decision.
 * @property {HTMLElement} [observedEl] - The element whose width drives the decision; defaults to the attached element.
 * @property {boolean} [active] - Whether to track this element; defaults to true.
 * @property {unknown} [remeasureOn] - Value (or array of values) consumed purely for re-measure reactivity.
 */

/**
 * @typedef DFitSignature
 * @property {HTMLElement} Element
 * @property {object} Args
 * @property {[FitCompute]} Args.Positional
 * @property {DFitNamedArgs} Args.Named
 */

/**
 * Bridges an element to the shared {@link registerFit fit coordinator} so a
 * width-driven decision (fold an action row, swap a compact layout, …) is
 * computed and applied through the one shared observer + batched
 * read-all-then-write-all pass.
 *
 * Positional args:
 *  - `compute` — `(availWidth, element, observedEl) => decision`. The one
 *    consumer function: given the observed element's available width, read
 *    whatever else the decision needs (usually sub-element widths of `element`,
 *    the element this modifier is attached to) and return a decision, typically
 *    a short string from a closed set. It runs in the coordinator's SHARED read
 *    phase — it MUST NOT write to the DOM. Most consumers only use the first
 *    two parameters; `observedEl` is passed last for the rare consumer that
 *    observes one element while attached to another and needs both.
 *
 * Named args:
 *  - `@attribute` — write strategy A: the coordinator sets this attribute to
 *    each changed decision (a string) on the OBSERVED element, and clears it on
 *    teardown. A stylesheet keys off it. Mutually exclusive with `@onChange`.
 *  - `@onChange` — write strategy B: `(decision) => …`, invoked with each
 *    changed decision, for JS/reactive state. Mutually exclusive with
 *    `@attribute`.
 *  - `@observedEl` — the element whose width drives the decision. Defaults to
 *    the element this modifier is attached to. Pass it when the attached
 *    element's own width depends on the decision (which would oscillate) — the
 *    available width then comes from a stable container instead.
 *  - `@active` — whether to track this element; defaults to `true`. Use for
 *    "only while selected/visible" cases; while false the registration is
 *    dropped (and an attribute-strategy attribute cleared).
 *  - `@remeasureOn` — any value (or array of values) consumed purely for
 *    reactivity: when a consumed value's tracking tag invalidates, this
 *    modifier re-runs and re-measures. Pass the tracked-derived values that
 *    change the content's natural width without resizing the observed box (an
 *    items list, a label, a sub-mode flag) — an `{{array …}}` of tracked
 *    reads, a `@cached` getter, or a tracked collection (whose in-place
 *    mutations DO re-run). A plain untracked object mutated in place never
 *    re-runs. A plain resize needs nothing here; the observer catches it.
 *
 * Pitfalls (each fails silently — no error, just a wrong or stale decision):
 *  - Writing to the DOM from `compute`. It runs in a READ phase shared by every
 *    target; a single write there forces a mid-batch reflow and defeats the
 *    batching for ALL of them, not just this one. Measure only.
 *  - Observing an element whose own width the decision changes. It oscillates
 *    (fold → the box gets wider → unfold → it gets narrower → fold …). Observe a
 *    stable ancestor through `@observedEl` whenever the decision resizes the
 *    attached element.
 *  - Expecting `@remeasureOn` to react to a value it cannot track. Re-measuring
 *    is driven by TAG INVALIDATION, so an untracked value — or a plain object or
 *    array mutated in place — never re-runs and the content-driven re-measure is
 *    silently skipped. Pass tracked-derived values (see the arg above).
 *  - Returning an unstable decision from `compute`. Writes are diffed against
 *    the last decision with `equals` (default `Object.is`), so a `compute` that
 *    builds a fresh object or array each call re-applies on every pass (a
 *    needless attribute write or `onChange` re-render). Return a primitive, or
 *    pass a matching `equals`.
 *
 * @example Fold a strip's labels via a stylesheet, observing the strip itself
 *  <nav class="strip" {{dFit this.computeFit attribute="data-fit" remeasureOn=@items}}>
 *
 * @example Observe a container, react in JS, track only while selected
 *  <div {{dFit this.computeFit observedEl=@containerEl onChange=this.onFitChange active=this.isSelected}}>
 *
 * @extends {Modifier<DFitSignature>}
 */
export default class DFit extends Modifier {
  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => unregisterFit(instance));
  }

  /**
   * @param {HTMLElement} element
   * @param {[FitCompute]} positional
   * @param {DFitNamedArgs} named
   */
  modify(element, [compute], named) {
    const { attribute, onChange, remeasureOn } = named;

    // Consumed purely for reactivity: reading the value (and each element of an
    // array value) entangles its tracking tags, so a tracked content change
    // re-runs this modifier — the re-measure path.
    if (Array.isArray(remeasureOn)) {
      for (const value of remeasureOn) {
        void value;
      }
    } else {
      void remeasureOn;
    }

    const observedEl = named.observedEl ?? element;

    if (!(named.active ?? true) || !observedEl) {
      unregisterFit(this);
      return;
    }

    // Keyed by this modifier instance, so each use is an independent
    // registration even when several observe the same element. Re-registering
    // re-measures (and the coordinator preserves the last decision while the
    // observed element is unchanged, or swaps observation to a new one).
    registerFit({
      key: this,
      observedEl,
      compute: (availWidth, obsEl) => compute(availWidth, element, obsEl),
      attribute,
      onChange,
    });
  }
}
