import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";

export default class FkControlMenuItem extends Component {
  @action
  handleInput() {
    this.args.menuApi.close();

    if (this.args.action) {
      this.args.action(this.args.value, this.args.label, {
        setValue: this.args.setValue,
        setLabel: this.args.setLabel,
      });
    } else {
      this.args.setValue(this.args.value);
      this.args.setLabel(this.args.label);
    }
  }

  <template>
    <@item>
      <DButton
        @action={{this.handleInput}}
        class="btn-transparent"
        @icon={{@icon}}
        ...attributes
      >
        {{@label}}
      </DButton>
    </@item>
  </template>
}
