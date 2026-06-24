// @ts-check
import Component from "@glimmer/component";
import { action } from "@ember/object";
import DSegmentedControl from "discourse/components/d-segmented-control";

/**
 * Renders an enum arg as a segmented control (an animated, single-select
 * button group) instead of a dropdown or radio list. Used from the generic
 * form's FormKit custom slot for args declaring `ui.control: "segmented"`.
 *
 * Items are built from the field's `enum` values (`@options`) and the optional
 * `ui.optionIcons` map (`@optionIcons`): each option shows its icon when one is
 * mapped, plus the value as its label so the control stays accessible (the
 * label text is in the DOM for assistive tech). Value reads from `@custom.value`
 * and selection writes via `@custom.set`, routing through the form's `onSet`
 * like every other control.
 */
export default class InspectorSegmentedField extends Component {
  get items() {
    const options = this.args.options ?? [];
    const icons = this.args.optionIcons ?? {};
    return options.map((value) => ({
      value,
      label: value,
      icon: icons[value],
    }));
  }

  @action
  onSelect(value) {
    this.args.custom.set(value);
  }

  <template>
    <DSegmentedControl
      class="wireframe-segmented-field"
      @items={{this.items}}
      @value={{@custom.value}}
      @name={{@custom.name}}
      @onSelect={{this.onSelect}}
    />
  </template>
}
