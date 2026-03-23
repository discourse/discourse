import Component from "@glimmer/component";
import { action } from "@ember/object";
import VariableInput from "../variable/input";

export default class ExpressionInput extends Component {
  get displayValue() {
    const val = this.args.field.value;
    if (typeof val === "string" && val.startsWith("=")) {
      return val.slice(1);
    }
    return val ?? "";
  }

  @action
  handleChange(value) {
    this.args.field.set(`=${value}`);
  }

  <template>
    <VariableInput
      @value={{this.displayValue}}
      @onChange={{this.handleChange}}
    />
  </template>
}
