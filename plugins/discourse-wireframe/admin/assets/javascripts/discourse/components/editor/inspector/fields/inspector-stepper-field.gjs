// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";

/**
 * A numeric stepper: a number input flanked by decrement / increment buttons,
 * for integer-ish counts (e.g. column / row counts). Always emits a `Number`.
 *
 * Driven the same two ways as the dimension control:
 *   - **Generic form:** `@custom` (FieldData) + `@schema`; reads
 *     `@custom.value`, writes `@custom.set`, and reads bounds / step from
 *     `@schema.min` / `@schema.max` / `@schema.ui.step`.
 *   - **Standalone:** `@value` + `@onChange` and `@min` / `@max` / `@step`
 *     props directly.
 *
 * The numeric value is clamped to `@min` / `@max` on every commit, and the
 * buttons disable at the respective bound.
 */
export default class InspectorStepperField extends Component {
  get #currentValue() {
    const raw = this.args.custom ? this.args.custom.value : this.args.value;
    return typeof raw === "number" && Number.isFinite(raw) ? raw : null;
  }

  get min() {
    return this.args.min ?? this.args.schema?.min ?? null;
  }

  get max() {
    return this.args.max ?? this.args.schema?.max ?? null;
  }

  get step() {
    return this.args.step ?? this.args.schema?.ui?.step ?? 1;
  }

  get numberValue() {
    return this.#currentValue;
  }

  get atMin() {
    return this.min != null && this.numberValue != null
      ? this.numberValue <= this.min
      : false;
  }

  get atMax() {
    return this.max != null && this.numberValue != null
      ? this.numberValue >= this.max
      : false;
  }

  @action
  decrement() {
    this.#nudge(-this.step);
  }

  @action
  increment() {
    this.#nudge(this.step);
  }

  @action
  setNumber(event) {
    const raw = event.target.value;
    if (raw === "") {
      this.#commit(null);
      return;
    }
    const next = parseFloat(raw);
    if (Number.isFinite(next)) {
      this.#commit(this.#clamp(next));
    }
  }

  #nudge(delta) {
    // An empty field nudges from the lower bound (or zero) so the first click
    // lands on a sensible value rather than NaN.
    const base = this.numberValue ?? this.min ?? 0;
    this.#commit(this.#clamp(base + delta));
  }

  #clamp(value) {
    let next = value;
    if (this.min != null) {
      next = Math.max(this.min, next);
    }
    if (this.max != null) {
      next = Math.min(this.max, next);
    }
    return next;
  }

  #commit(value) {
    if (this.args.custom) {
      this.args.custom.set(value);
    } else {
      this.args.onChange?.(value);
    }
  }

  <template>
    <div class="wireframe-stepper-field">
      <DButton
        class="btn-flat wireframe-stepper-field__btn"
        @icon="minus"
        @disabled={{this.atMin}}
        @action={{this.decrement}}
        @ariaLabel="wireframe.inspector.controls.decrement"
      />
      <input
        type="number"
        class="wireframe-stepper-field__number"
        min={{this.min}}
        max={{this.max}}
        step={{this.step}}
        value={{this.numberValue}}
        aria-label={{@ariaLabel}}
        {{on "change" this.setNumber}}
      />
      <DButton
        class="btn-flat wireframe-stepper-field__btn"
        @icon="plus"
        @disabled={{this.atMax}}
        @action={{this.increment}}
        @ariaLabel="wireframe.inspector.controls.increment"
      />
    </div>
  </template>
}
