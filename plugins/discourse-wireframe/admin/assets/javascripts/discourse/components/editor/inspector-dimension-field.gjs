// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import { formatDimension, parseDimension } from "../../lib/css-dimension";

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
export default class InspectorDimensionField extends Component {
  /**
   * The working unit, used when the stored value carries none yet (an empty
   * field) and as the unit written on the next numeric edit. Seeded from the
   * current value's unit, falling back to the default. Read from the template
   * (the unit `<select>`), so it stays unprefixed.
   */
  @tracked selectedUnit;

  constructor() {
    super(...arguments);
    this.selectedUnit = this.#parsed?.unit || this.defaultUnit;
  }

  get #currentValue() {
    return this.args.custom ? this.args.custom.value : this.args.value;
  }

  get #parsed() {
    return parseDimension(this.#currentValue);
  }

  /** Allowed units; absence means the control is unitless. */
  get units() {
    return this.args.units ?? this.args.schema?.ui?.units ?? null;
  }

  get isUnitless() {
    if (this.args.unitless != null) {
      return this.args.unitless;
    }
    return !this.units?.length;
  }

  /** Default / suffix unit: explicit prop, schema hint, then first allowed unit. */
  get defaultUnit() {
    return (
      this.args.unit ?? this.args.schema?.ui?.unit ?? this.units?.[0] ?? ""
    );
  }

  get min() {
    return this.args.min ?? this.args.schema?.min ?? null;
  }

  get max() {
    return this.args.max ?? this.args.schema?.max ?? null;
  }

  get step() {
    return this.args.step ?? this.args.schema?.ui?.step ?? "any";
  }

  /** The slider only makes sense with both bounds to map the track onto. */
  get showSlider() {
    const enabled = this.args.slider ?? this.args.schema?.ui?.slider ?? false;
    return enabled && this.min != null && this.max != null;
  }

  /** The numeric part of the current value, or `null` for an empty field. */
  get numberValue() {
    return this.#parsed?.value ?? null;
  }

  /**
   * The working unit: the user's explicit selection wins (so picking a unit
   * sticks for the next numeric edit even before the value round-trips), then
   * the stored value's unit, then the default.
   */
  get displayUnit() {
    return this.selectedUnit || this.#parsed?.unit || this.defaultUnit;
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
      this.#commitNumber(next);
    }
  }

  @action
  setSlider(event) {
    const next = parseFloat(event.target.value);
    if (Number.isFinite(next)) {
      this.#commitNumber(next);
    }
  }

  @action
  setUnit(event) {
    this.selectedUnit = event.target.value;
    // Reserialize the existing number under the new unit; nothing to write yet
    // when the field is empty.
    if (this.numberValue != null) {
      this.#commit(formatDimension(this.numberValue, this.selectedUnit));
    }
  }

  #commitNumber(value) {
    const clamped = this.#clamp(value);
    const unit = this.isUnitless ? "" : this.displayUnit;
    this.#commit(formatDimension(clamped, unit));
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
