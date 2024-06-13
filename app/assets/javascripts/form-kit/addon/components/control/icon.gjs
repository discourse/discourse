import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import IconPicker from "select-kit/components/icon-picker";

export default class FkControlIcon extends Component {
  @action
  handleInput(value) {
    if (this.args.onSet) {
      this.args.onSet(value, { set: this.args.set });
    } else {
      this.args.setValue(value);
    }
  }

  @action
  handleDestroy() {
    this.args.setValue(undefined);
  }

  <template>
    <IconPicker
      @value={{@value}}
      @onlyAvailable={{true}}
      @options={{hash
        maximum=1
        disabled=@disabled
        caretDownIcon="angle-down"
        caretUpIcon="angle-up"
        icons=@value
      }}
      @onChange={{this.handleInput}}
      class="d-form__control-icon"
      {{willDestroy this.handleDestroy}}
    />
  </template>
}
