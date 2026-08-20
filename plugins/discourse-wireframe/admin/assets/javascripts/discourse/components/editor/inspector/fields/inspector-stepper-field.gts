import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";

interface InspectorStepperFieldSignature {
  /** Numeric value, constraints, and FormKit integration. */
  Args: {
    /** Accessible label for the numeric input. */
    ariaLabel?: string;
    /** FormKit field data used by the generic form. */
    custom?: {
      /** Current FormKit field value. */
      value: unknown;
      /** Writes a new FormKit field value. */
      set: (
        /** New field value. */
        value: unknown
      ) => void;
    };
    /** Maximum accepted value. */
    max?: number;
    /** Minimum accepted value. */
    min?: number;
    /** Called with a new standalone value. */
    onChange?: (
      /** New standalone numeric value. */
      value: number | null
    ) => void;
    /** Schema constraints supplied by the inspector. */
    schema?: {
      /** Minimum schema value. */
      min?: number;
      /** Maximum schema value. */
      max?: number;
      /** Numeric-control presentation hints. */
      ui?: {
        /** Amount added or removed by each action. */
        step?: number;
      };
    };
    /** Amount added or removed by each action. */
    step?: number;
    /** Current standalone value. */
    value?: unknown;
  };
}

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
export default class InspectorStepperField extends Component<InspectorStepperFieldSignature> {
  /** Current finite numeric value, or `null` when the field is empty. */
  get #currentValue(): number | null {
    const raw = this.args.custom ? this.args.custom.value : this.args.value;
    return typeof raw === "number" && Number.isFinite(raw) ? raw : null;
  }

  /** Effective minimum value. */
  get min(): number | null {
    return this.args.min ?? this.args.schema?.min ?? null;
  }

  /** Effective maximum value. */
  get max(): number | null {
    return this.args.max ?? this.args.schema?.max ?? null;
  }

  /** Effective increment size. */
  get step(): number {
    return this.args.step ?? this.args.schema?.ui?.step ?? 1;
  }

  /** Numeric value exposed to the template. */
  get numberValue(): number | null {
    return this.#currentValue;
  }

  /** Whether decrementing would exceed the minimum. */
  get atMin(): boolean {
    return this.min != null && this.numberValue != null
      ? this.numberValue <= this.min
      : false;
  }

  /** Whether incrementing would exceed the maximum. */
  get atMax(): boolean {
    return this.max != null && this.numberValue != null
      ? this.numberValue >= this.max
      : false;
  }

  /** Decrements the current value by one effective step. */
  @action
  decrement(): void {
    this.#nudge(-this.step);
  }

  /** Increments the current value by one effective step. */
  @action
  increment(): void {
    this.#nudge(this.step);
  }

  /**
   * Commits a value entered directly into the numeric input.
   *
   * @param event - Numeric input change event.
   */
  @action
  setNumber(event: Event): void {
    if (!(event.target instanceof HTMLInputElement)) {
      return;
    }
    const input = event.target;
    const raw = input.value;
    if (raw === "") {
      this.#commit(null);
      return;
    }
    const next = parseFloat(raw);
    if (Number.isFinite(next)) {
      this.#commit(this.#clamp(next));
    }
  }

  /** Moves the current value by the requested delta. */
  #nudge(
    /** Signed amount to add to the current value. */
    delta: number
  ): void {
    // An empty field nudges from the lower bound (or zero) so the first click
    // lands on a sensible value rather than NaN.
    const base = this.numberValue ?? this.min ?? 0;
    this.#commit(this.#clamp(base + delta));
  }

  /** Clamps a candidate value to the effective bounds. */
  #clamp(
    /** Candidate numeric value. */
    value: number
  ): number {
    let next = value;
    if (this.min != null) {
      next = Math.max(this.min, next);
    }
    if (this.max != null) {
      next = Math.min(this.max, next);
    }
    return next;
  }

  /** Commits a value through the active FormKit or standalone callback. */
  #commit(
    /** Numeric value to commit, or `null` to clear the field. */
    value: number | null
  ): void {
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
