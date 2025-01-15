import Component from "@ember/component";
import { attributeBindings, tagName } from "@ember-decorators/component";
import $ from "jquery";
import discourseComputed from "discourse/lib/decorators";

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

  @discourseComputed("value", "selection")
  checked(value, selection) {
    return value === selection;
  }
}
