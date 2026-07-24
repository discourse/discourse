import { action } from "@ember/object";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import DIconGridPicker from "discourse/ui-kit/d-icon-grid-picker";

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
