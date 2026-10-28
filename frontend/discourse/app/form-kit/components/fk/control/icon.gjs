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
      class="form-kit__control-icon"
      @allowClear={{@allowClear}}
      @disabled={{@field.disabled}}
      @onChange={{this.handleInput}}
      @onlyAvailable={{@onlyAvailable}}
      @showCaret={{true}}
      @showSelectedName={{true}}
      @value={{@field.value}}
    />
  </template>
}
