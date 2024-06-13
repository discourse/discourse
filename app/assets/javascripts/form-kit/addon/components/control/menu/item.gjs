import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";

export default class FKControlMenuItem extends Component {
  @action
  handleInput() {
    this.args.menuApi.close();

    if (this.args.action) {
      this.args.action(this.args.value, {
        setValue: this.args.setValue,
      });
    } else {
      this.args.setValue(this.args.value);
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
