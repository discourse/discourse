import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import type { ArgSchema } from "discourse/blocks/types";
import { eq } from "discourse/truth-helpers";
import {
  formatDimension,
  type ParsedDimension,
  parseDimension,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/css-dimension";

type DimensionFieldData = {
  /** Current FormKit field value. */
  value: unknown;
  /** Writes a replacement FormKit field value. */
  set: (value: unknown) => void;
};

// TODO(devxp-typescript-pending): replace `DimensionFieldData` once FormKit
// exports the type of the field data yielded by a custom control.

interface InspectorDimensionFieldSignature {
  /** Dimension value and control configuration. */
  Args: {
    /** FormKit field data when rendered as a custom control. */
    custom?: DimensionFieldData;
    /** Standalone dimension value. */
    value?: string | number | null;
    /** Handles standalone value changes. */
    onChange?: (value: unknown) => void;
    /** CSS units the author can select. */
    units?: string[];
    /** Default or display-only unit. */
    unit?: string;
    /** Whether the persisted value omits its display unit. */
    unitless?: boolean;
    /** Minimum permitted numeric value. */
    min?: number;
    /** Maximum permitted numeric value. */
    max?: number;
    /** Numeric input step. */
    step?: number | "any";
    /** Whether to render the bounded slider. */
    slider?: boolean;
    /** Canonical block argument schema supplying fallback configuration. */
    schema?: ArgSchema;
  };
}

/**
 * A CSS-dimension control: a numeric input with an optional inline slider and
 * either a unit selector (px / rem / % / em) or a static unit suffix.
 *
 * Two ways to drive it:
 *   - **Generic form (FormKit custom slot):** pass `@custom` (the yielded
 *     FieldData) and `@schema` (the arg definition). The control reads the
 *     current value from `@custom.value` and writes via `@custom.set`, so edits
 *     route through the form's `onSet` handler like every other field.
 *     Configuration (units / step / slider / bounds) is read from
 *     `@schema.ui.*` and `@schema.min` / `@schema.max`.
 *   - **Standalone:** pass `@value` + `@onChange` and the configuration props
 *     (`@units`, `@unit`, `@min`, `@max`, `@step`, `@slider`, `@unitless`)
 *     directly. The bespoke layout form uses this path for the gap control.
 *
 * Value shape: when the control is **unitless** (no `@units` declared, or
 * `@unitless`), it emits a bare `Number` and shows `@unit` as a read-only
 * suffix — so a unitless arg (e.g. gap, stored as a rem count) is never coerced
 * to a string. Otherwise it emits a CSS string like `"16rem"`. The numeric part
 * is clamped to `@min` / `@max` on commit so an out-of-range entry is corrected
 * here rather than silently rejected downstream.
 */
export default class InspectorDimensionField extends Component<InspectorDimensionFieldSignature> {
  /**
   * The working unit, used when the stored value carries none yet (an empty
   * field) and as the unit written on the next numeric edit. Seeded from the
   * current value's unit, falling back to the default. Read from the template
   * (the unit `<select>`), so it stays unprefixed.
   */
  @tracked selectedUnit: string;

  /**
   * Creates a dimension control and seeds its working unit.
   *
   * @param owner - Ember owner for the component instance.
   * @param args - Dimension value and control configuration.
   */
  constructor(owner: Owner, args: InspectorDimensionFieldSignature["Args"]) {
    super(owner, args);
    this.selectedUnit = this.#parsed?.unit || this.defaultUnit;
  }

  /** Current dimension value normalized to the supported scalar shapes. */
  get #currentValue(): string | number | null {
    const value = this.args.custom ? this.args.custom.value : this.args.value;

    return typeof value === "string" || typeof value === "number"
      ? value
      : null;
  }

  /** Parsed numeric and unit portions of the current value. */
  get #parsed(): ParsedDimension | null {
    return parseDimension(this.#currentValue);
  }

  /** Allowed units; absence means the control is unitless. */
  get units(): string[] | null {
    return this.args.units ?? this.args.schema?.ui?.units ?? null;
  }

  /** Whether the persisted value omits its display unit. */
  get isUnitless(): boolean {
    if (this.args.unitless != null) {
      return this.args.unitless;
    }
    return !this.units?.length;
  }

  /** Default / suffix unit: explicit prop, schema hint, then first allowed unit. */
  get defaultUnit(): string {
    return (
      this.args.unit ?? this.args.schema?.ui?.unit ?? this.units?.[0] ?? ""
    );
  }

  /** Minimum permitted numeric value. */
  get min(): number | null {
    return this.args.min ?? this.args.schema?.min ?? null;
  }

  /** Maximum permitted numeric value. */
  get max(): number | null {
    return this.args.max ?? this.args.schema?.max ?? null;
  }

  /** Numeric input and slider step. */
  get step(): number | "any" {
    return this.args.step ?? this.args.schema?.ui?.step ?? "any";
  }

  /** The slider only makes sense with both bounds to map the track onto. */
  get showSlider(): boolean {
    const enabled = this.args.slider ?? this.args.schema?.ui?.slider ?? false;
    return enabled && this.min != null && this.max != null;
  }

  /** The numeric part of the current value, or `null` for an empty field. */
  get numberValue(): number | null {
    return this.#parsed?.value ?? null;
  }

  /**
   * The working unit: the user's explicit selection wins (so picking a unit
   * sticks for the next numeric edit even before the value round-trips), then
   * the stored value's unit, then the default.
   */
  get displayUnit(): string {
    return this.selectedUnit || this.#parsed?.unit || this.defaultUnit;
  }

  /**
   * Commits a manually entered number.
   *
   * @param event - Number-input change event.
   */
  @action
  setNumber(
    event: Event & {
      /** Number input that emitted the event. */
      currentTarget: Element;
    }
  ): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    const raw = event.currentTarget.value;
    if (raw === "") {
      this.#commit(null);
      return;
    }
    const next = parseFloat(raw);
    if (Number.isFinite(next)) {
      this.#commitNumber(next);
    }
  }

  /**
   * Commits the slider's live numeric value.
   *
   * @param event - Range-input event.
   */
  @action
  setSlider(
    event: Event & {
      /** Range input that emitted the event. */
      currentTarget: Element;
    }
  ): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    const next = parseFloat(event.currentTarget.value);
    if (Number.isFinite(next)) {
      this.#commitNumber(next);
    }
  }

  /**
   * Re-serializes the current number under a selected unit.
   *
   * @param event - Unit-select change event.
   */
  @action
  setUnit(
    event: Event & {
      /** Unit select that emitted the event. */
      currentTarget: Element;
    }
  ): void {
    if (!(event.currentTarget instanceof HTMLSelectElement)) {
      return;
    }
    this.selectedUnit = event.currentTarget.value;
    // Reserialize the existing number under the new unit; nothing to write yet
    // when the field is empty.
    if (this.numberValue != null) {
      this.#commit(formatDimension(this.numberValue, this.selectedUnit));
    }
  }

  /** @param value - Numeric value to clamp and serialize. */
  #commitNumber(value: number): void {
    const clamped = this.#clamp(value);
    const unit = this.isUnitless ? "" : this.displayUnit;
    this.#commit(formatDimension(clamped, unit));
  }

  /**
   * Clamps a number to the configured bounds.
   *
   * @param value - Number to clamp.
   * @returns The bounded number.
   */
  #clamp(value: number): number {
    let next = value;
    if (this.min != null) {
      next = Math.max(this.min, next);
    }
    if (this.max != null) {
      next = Math.min(this.max, next);
    }
    return next;
  }

  /** @param value - Dimension value to send to the active consumer. */
  #commit(value: string | number | null): void {
    if (this.args.custom) {
      this.args.custom.set(value);
    } else {
      this.args.onChange?.(value);
    }
  }

  <template>
    <div
      class="wireframe-dimension-field
        {{if this.showSlider 'wireframe-dimension-field--with-slider'}}"
    >
      {{#if this.showSlider}}
        <input
          type="range"
          class="wireframe-dimension-field__slider"
          min={{this.min}}
          max={{this.max}}
          step={{this.step}}
          value={{this.numberValue}}
          {{on "input" this.setSlider}}
        />
      {{/if}}

      <div class="wireframe-dimension-field__entry">
        {{! Commit on `change` (blur / Enter), not `input`: the value reads back
          live, so committing every keystroke would fight the caret mid-type.
          The slider above stays live on `input` for drag feedback. }}
        <input
          type="number"
          class="wireframe-dimension-field__number"
          min={{this.min}}
          max={{this.max}}
          step={{this.step}}
          value={{this.numberValue}}
          {{on "change" this.setNumber}}
        />

        {{#if this.isUnitless}}
          <span class="wireframe-dimension-field__suffix">
            {{this.defaultUnit}}
          </span>
        {{else}}
          <select
            class="wireframe-dimension-field__unit"
            {{on "change" this.setUnit}}
          >
            {{#each this.units as |unit|}}
              <option value={{unit}} selected={{eq unit this.displayUnit}}>
                {{unit}}
              </option>
            {{/each}}
          </select>
        {{/if}}
      </div>
    </div>
  </template>
}
