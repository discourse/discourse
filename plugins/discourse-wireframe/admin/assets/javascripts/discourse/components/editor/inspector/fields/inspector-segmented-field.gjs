// @ts-check
import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DSegmentedControl from "discourse/components/d-segmented-control";
import ComboBox from "discourse/select-kit/components/combo-box";

// The most options a segmented row is allowed to show regardless of width. Even
// with room, past this many segments the row is too busy to scan, so we always
// fall back to a dropdown.
const SEGMENT_MAX = 6;

// Rough width, in pixels, one icon segment needs to stay tappable and legible,
// plus the fixed chrome (panel + form padding) around the control. The fold
// decision compares the inspector rail's width to `count * MIN_SEGMENT_PX +
// PANEL_INSET`. Tuned so the default six-icon controls stay segments at the
// default rail width and fold only once the rail is dragged narrower.
const MIN_SEGMENT_PX = 36;
const PANEL_INSET = 48;

/**
 * The inspector's one enum picker. Renders a single-select choice as a segmented
 * control — each option shows its icon when it has one, otherwise its label (so
 * a mixed set like "Auto" + alignment arrows reads naturally) — and folds to a
 * dropdown when the row would be cramped.
 *
 * Because the inspector rail is resizable, the fold is driven by the rail's
 * width: drag the rail narrow and the segments fold to a dropdown; widen it and
 * they return. The width comes from the `wireframe-rail` service (the source of
 * truth that also drives the rail's CSS), so the decision is a pure, reactive
 * getter — no per-field measurement, flicker, or resize loop. `SEGMENT_MAX`
 * remains a hard cap independent of width.
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
  @service wireframeRail;

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
   * Fold to the dropdown when there are too many options for a row, or when the
   * inspector rail is too narrow to fit `count` segments comfortably.
   *
   * @returns {boolean}
   */
  get useDropdown() {
    const count = this.items.length;
    if (count > SEGMENT_MAX) {
      return true;
    }
    return (
      this.wireframeRail.rightRailWidth < count * MIN_SEGMENT_PX + PANEL_INSET
    );
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
