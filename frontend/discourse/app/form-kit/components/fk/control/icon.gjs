import { hash } from "@ember/helper";
import { action } from "@ember/object";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import IconPicker from "discourse/select-kit/components/icon-picker";

export default class FKControlIcon extends FKBaseControl {
  static controlType = "icon";

  @action
  handleInput(value) {
    this.args.field.set(value);
  }

  <template>
    <IconPicker
      @value={{readonly @field.value}}
      @onlyAvailable={{true}}
      @options={{hash
        maximum=1
        disabled=@field.disabled
        caretDownIcon="angle-down"
        caretUpIcon="angle-up"
        icons=@field.value
      }}
      @onChange={{this.handleInput}}
      class="form-kit__control-icon"
    />
  </template>
}
