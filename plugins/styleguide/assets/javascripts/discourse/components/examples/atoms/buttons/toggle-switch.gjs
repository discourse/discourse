import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";

export default class ToggleSwitchExample extends Component {
  @tracked state = true;

  @action
  toggle() {
    this.state = !this.state;
  }

  <template>
    <DToggleSwitch @state={{this.state}} {{on "click" this.toggle}} />
    <DToggleSwitch
      disabled="true"
      title="Disabled with state=true"
      @state={{true}}
    />
    <DToggleSwitch
      disabled="true"
      title="Disabled with state=false"
      @state={{false}}
    />
  </template>
}
