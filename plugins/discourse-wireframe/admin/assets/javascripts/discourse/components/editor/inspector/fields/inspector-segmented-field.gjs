// @ts-check
import Component from "@glimmer/component";
import { action } from "@ember/object";
import DSegmentedControl from "discourse/components/d-segmented-control";
import ComboBox from "discourse/select-kit/components/combo-box";
import DFitSwap from "discourse/ui-kit/d-fit-swap";

// The most options a segmented row is allowed to show regardless of width. Even
// with room, past this many segments the row is too busy to scan, so we always
// fall back to a dropdown.
const SEGMENT_MAX = 6;

/**
 * The inspector's one enum picker. Renders a single-select choice as a segmented
 * control — each option shows its icon when it has one, otherwise its label (so
 * a mixed set like "Auto" + alignment arrows reads naturally) — and folds to a
 * dropdown when the row would be cramped.
 *
 * The fold is width-driven through the core `DFitSwap` component: the segmented
 * row collapses to the dropdown whenever its natural width no longer fits the
 * field (drag the inspector rail narrow and it folds; widen it and the segments
 * return). `SEGMENT_MAX` remains a hard cap independent of width.
 *
 * Both `DSegmentedControl` and `ComboBox` carry their own keyboard / screen-reader
 * behavior; folding only swaps which one renders.
 *
 * Two ways to drive it:
 *   - **Generic form (FormKit custom slot):** pass `@custom` (the yielded
 *     FieldData). Reads `@custom.value`, writes `@custom.set`.
 *   - **Standalone:** pass `@value` + `@onChange` (the bespoke layout form).
 *
 * Items come either pre-built via `@items` (`{value, label, icon?, title?}` — the
 * layout form supplies axis-aware icons) or from `@options` + the optional
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
   * `true` when there are too many options for a segmented row no matter how
   * wide the field is; width-driven folding is handled by `DFitSwap` instead.
   *
   * @returns {boolean}
   */
  get exceedsSegmentMax() {
    return this.items.length > SEGMENT_MAX;
  }

  /**
   * Items for `DSegmentedControl`. Drop the label on any option that has an icon
   * so iconned options render icon-only while icon-less ones keep their text — a
   * per-option choice, not all-or-nothing.
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
    {{#if this.exceedsSegmentMax}}
      <ComboBox
        class="wireframe-segmented-field__dropdown"
        @content={{this.items}}
        @value={{this.currentValue}}
        @nameProperty="label"
        @valueProperty="value"
        @onChange={{this.commit}}
      />
    {{else}}
      <DFitSwap @remeasureOn={{this.items}}>
        <:full>
          <DSegmentedControl
            class="wireframe-segmented-field"
            @items={{this.segmentItems}}
            @value={{this.currentValue}}
            @name={{this.name}}
            @onSelect={{this.commit}}
          />
        </:full>
        <:collapsed>
          <ComboBox
            class="wireframe-segmented-field__dropdown"
            @content={{this.items}}
            @value={{this.currentValue}}
            @nameProperty="label"
            @valueProperty="value"
            @onChange={{this.commit}}
          />
        </:collapsed>
      </DFitSwap>
    {{/if}}
  </template>
}
