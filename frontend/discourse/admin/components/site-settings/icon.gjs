import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import IconPicker from "discourse/select-kit/components/icon-picker";

export default class Icon extends Component {
  @action
  onChangeIcon(value) {
    this.args.changeValueCallback(value);
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
      @onChange={{this.onChangeIcon}}
    />
  </template>
}
