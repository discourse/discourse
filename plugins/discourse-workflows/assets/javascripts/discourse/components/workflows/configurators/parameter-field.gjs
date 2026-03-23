import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";

export default class ParameterField extends Component {
  get displayValue() {
    const val = this.args.value;
    if (!val || typeof val !== "string") {
      return val ?? "";
    }
    return val.startsWith("=") ? val.slice(1) : val;
  }

  @action
  handleInput(event) {
    this.args.onChange(`=${event.target.value}`);
  }

  <template>
    <input
      type="text"
      class="workflows-parameter-field"
      value={{this.displayValue}}
      placeholder={{@placeholder}}
      {{on "input" this.handleInput}}
    />
  </template>
}
