import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DToggleSwitch from "discourse/components/d-toggle-switch";

export default class FKControlToggle extends Component {
  static controlType = "toggle";

  @action
  handleInput() {
    this.args.field.set(!this.args.field.value);
  }

  <template>
    <DToggleSwitch
      @state={{@field.value}}
      disabled={{@field.disabled}}
      {{on "click" this.handleInput}}
      class="form-kit__control-toggle"
    />
  </template>
}
