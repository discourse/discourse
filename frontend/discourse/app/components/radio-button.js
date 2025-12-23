/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { attributeBindings, tagName } from "@ember-decorators/component";
import $ from "jquery";

@tagName("input")
@attributeBindings(
  "name",
  "type",
  "value",
  "checked:checked",
  "disabled:disabled"
)
export default class RadioButton extends Component {
  type = "radio";

  click() {
    const value = $(this.element).val();

    if (this.onChange) {
      this.onChange(value);
    } else {
      if (this.selection === value) {
        this.set("selection", undefined);
      }
      this.set("selection", value);
    }
  }

  @computed("value", "selection")
  get checked() {
    return this.value === this.selection;
  }
}
