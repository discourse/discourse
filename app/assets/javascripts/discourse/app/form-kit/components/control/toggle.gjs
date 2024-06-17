import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DToggleSwitch from "discourse/components/d-toggle-switch";

export default class FKControlToggle extends Component {
  @action
  handleInput() {
    this.args.field.set(!this.args.value);
  }

  <template>
    <DToggleSwitch @state={{@value}} {{on "click" this.handleInput}} />
  </template>
}
