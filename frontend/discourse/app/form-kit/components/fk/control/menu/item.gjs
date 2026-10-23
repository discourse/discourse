import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";

export default class FKControlMenuItem extends Component {
  @action
  handleInput() {
    this.args.menuApi.close();

    if (this.args.action) {
      this.args.action(this.args.value, {
        set: this.args.set,
      });
    } else {
      this.args.field.set(this.args.value);
    }
  }

  <template>
    <@item class="form-kit__control-menu-item" data-value={{@value}}>
      <DButton
        class="btn-flat"
        ...attributes
        @action={{this.handleInput}}
        @icon={{@icon}}
      >
        {{yield}}
      </DButton>
    </@item>
  </template>
}
