import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DToggleSwitch from "discourse/components/d-toggle-switch";

export default class FormControlToggle extends Component {
  @action
  handleInput() {
    console.log("handleInput should set", !this.args.value);
    this.args.setValue(!this.args.value);
  }

  <template>
    {{@value}}
    <DToggleSwitch @state={{@value}} {{on "click" this.handleInput}} />
  </template>
}
