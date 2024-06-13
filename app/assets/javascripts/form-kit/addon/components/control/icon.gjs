import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import IconPicker from "select-kit/components/icon-picker";

export default class FKControlIcon extends Component {
  @action
  handleInput(value) {
    if (this.args.field.onSet) {
      this.args.field.onSet(value, { set: this.args.set });
    } else {
      this.args.setValue(value);
    }
  }

  <template>
    <IconPicker
      @value={{@value}}
      @onlyAvailable={{true}}
      @options={{hash
        maximum=1
        disabled=@field.disabled
        caretDownIcon="angle-down"
        caretUpIcon="angle-up"
        icons=@value
      }}
      @onChange={{this.handleInput}}
      class="form-kit__control-icon"
    />
  </template>
}
