import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import IconPicker from "select-kit/components/icon-picker";

export default class FKControlIcon extends Component {
  static controlType = "icon";

  @action
  handleInput(value) {
    this.args.field.set(value);
  }

  <template>
    <IconPicker
      @value={{readonly @value}}
      @onlyAvailable={{true}}
      @options={{hash
        maximum=1
        disabled=@disabled
        caretDownIcon="angle-down"
        caretUpIcon="angle-up"
        icons=@value
      }}
      @onChange={{this.handleInput}}
      class="form-kit__control-icon"
    />
  </template>
}
