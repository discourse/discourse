import { action } from "@ember/object";
import DIconGridPicker from "discourse/components/d-icon-grid-picker";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";

export default class FKControlIcon extends FKBaseControl {
  static controlType = "icon";

  @action
  handleInput(value) {
    this.args.field.set(value);
  }

  <template>
    <DIconGridPicker
      @value={{@field.value}}
      @onChange={{this.handleInput}}
      @disabled={{@field.disabled}}
      @showCaret={{true}}
      @showSelectedName={{true}}
      class="form-kit__control-icon"
    />
  </template>
}
