// @ts-check
import Component from "@glimmer/component";
import { action } from "@ember/object";
import DSegmentedControl from "discourse/components/d-segmented-control";
import ComboBox from "discourse/select-kit/components/combo-box";

// A segmented row stays usable up to this many options; beyond it we fall back
// to a dropdown. Within the row, labels ellipsis-shrink (see the chrome SCSS),
// so width takes care of itself — only the option count drives the fallback.
const SEGMENT_MAX = 6;

/**
 * The inspector's one enum picker. Renders a single-select choice as a
 * segmented control — each option shows its icon when it has one, otherwise its
 * label (so a mixed set like "Auto" + alignment arrows reads naturally) — and
 * falls back to a dropdown only when the row would be cramped. The choice is
 * deterministic, from the option count + how many lack icons, so there's no
 * measurement, flicker, or resize loop. Icon segments fit the panel even at six
 * options, so the dropdown is a rare safety net.
 *
 * Two ways to drive it:
 *   - **Generic form (FormKit custom slot):** pass `@custom` (the yielded
 *     FieldData). Reads `@custom.value`, writes `@custom.set`.
 *   - **Standalone:** pass `@value` + `@onChange` (the bespoke layout form).
 *
 * Items come either pre-built via `@items` (`{value, label, icon?, title?}` —
 * the layout form supplies axis-aware icons) or from `@options` + the optional
 * `@optionIcons` map (the generic form), in which case the value doubles as the
 * label and tooltip.
 */
export default class InspectorSegmentedField extends Component {
  get currentValue() {
    return this.args.custom ? this.args.custom.value : this.args.value;
  }

  get name() {
    return this.args.name ?? this.args.custom?.name;
  }

  /** Normalized `{value, label, icon, title}` rows. */
  get items() {
    if (this.args.items) {
      return this.args.items.map((item) => ({
        ...item,
        title: item.title ?? item.label,
      }));
    }
    const options = this.args.options ?? [];
    const icons = this.args.optionIcons ?? {};
    return options.map((value) => ({
      value,
      label: value,
      icon: icons[value],
      title: value,
    }));
  }

  /**
   * Fall back to the dropdown only when there are too many options for a
   * segmented row to stay usable.
   *
   * @returns {boolean}
   */
  get useDropdown() {
    return this.items.length > SEGMENT_MAX;
  }

  /**
   * Items for `DSegmentedControl`. Drop the label on any option that has an icon
   * so iconned options render icon-only while icon-less ones keep their text —
   * a per-option choice, not all-or-nothing.
   */
  get segmentItems() {
    return this.items.map((item) => ({
      value: item.value,
      label: item.icon ? undefined : item.label,
      icon: item.icon,
      title: item.title,
    }));
  }

  @action
  commit(value) {
    if (this.args.custom) {
      this.args.custom.set(value);
    } else {
      this.args.onChange?.(value);
    }
  }

  <template>
    {{#if this.useDropdown}}
      <ComboBox
        class="wireframe-segmented-field__dropdown"
        @content={{this.items}}
        @value={{this.currentValue}}
        @nameProperty="label"
        @valueProperty="value"
        @onChange={{this.commit}}
      />
    {{else}}
      <DSegmentedControl
        class="wireframe-segmented-field"
        @items={{this.segmentItems}}
        @value={{this.currentValue}}
        @name={{this.name}}
        @onSelect={{this.commit}}
      />
    {{/if}}
  </template>
}
