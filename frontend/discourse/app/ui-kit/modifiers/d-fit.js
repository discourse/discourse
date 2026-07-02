// @ts-check
import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";
import { registerFit, unregisterFit } from "discourse/lib/fit-coordinator";

/**
 * Bridges an element to the shared {@link registerFit fit coordinator} so a
 * width-driven decision (fold an action row, swap a compact control, …) is
 * measured and applied through the one shared observer + batched pass.
 *
 * A thin lifecycle bridge: it registers while `active` and unregisters when the
 * element detaches, the observed element changes, or `active` goes false. All
 * measurement and decision logic lives in the coordinator and in the consumer's
 * own `@measure` / `@decide` / `@apply`.
 *
 * Named args:
 *  - `@measure` — `(attachedEl, observedEl) => data`. READS whatever the decision
 *    needs (sub-element widths, an item count) and returns opaque data. It is
 *    handed both the element this modifier is on and the observed element, so a
 *    consumer can observe one element's width while measuring another's parts.
 *    Must not write to the DOM.
 *  - `@decide` — `(availWidth, data) => decision`. Pure; maps the observed
 *    element's available width plus `data` to a decision (a value from a closed set).
 *  - `@apply` — `{ attribute: "data-x" }` (the coordinator sets it on `@targetEl`,
 *    defaulting to the observed element) OR `{ callback: (decision) => … }` (the
 *    coordinator invokes it with each CHANGED decision).
 *  - `@observedEl` — the element whose width is tracked. Defaults to the element
 *    this modifier is attached to. Its width should not depend on the decision.
 *  - `@targetEl` — attribute-strategy only: the element the attribute is written
 *    to. Defaults to the observed element.
 *  - `@active` — whether to track this element (e.g. only while selected/visible).
 *  - `@fingerprint` — read only to re-run this modifier (and thus re-measure)
 *    when width-affecting content changes without a resize; its value is unused.
 *  - `@equals` — optional decision equality for diffing (defaults to `Object.is`).
 */
export default class DFit extends Modifier {
  /** @type {HTMLElement|null} The observed element currently registered, if any. */
  #observedEl = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#teardown());
  }

  modify(element, _positional, named) {
    const { measure, decide, apply, targetEl, active, fingerprint, equals } =
      named;

    // Read purely to re-run when width-affecting content changes; value unused.
    void fingerprint;

    const observedEl = named.observedEl ?? element;

    // The observed element can arrive late or change — drop the old registration.
    if (observedEl !== this.#observedEl) {
      this.#teardown();
      this.#observedEl = observedEl ?? null;
    }

    if (!active || !this.#observedEl) {
      this.#teardown();
      return;
    }

    // Idempotent by key: re-registering re-measures (and preserves the last
    // decision), which is exactly what a fingerprint-driven re-run wants.
    registerFit({
      key: this.#observedEl,
      observedEl: this.#observedEl,
      measure: (obsEl) => measure(element, obsEl),
      decide,
      apply:
        "attribute" in apply
          ? {
              attribute: apply.attribute,
              targetEl: targetEl ?? this.#observedEl,
            }
          : apply,
      equals,
    });
  }

  #teardown() {
    if (this.#observedEl) {
      unregisterFit(this.#observedEl);
    }
  }
}
