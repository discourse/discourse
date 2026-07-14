import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";

export default class FKControlToggle extends FKBaseControl {
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
