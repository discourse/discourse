import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";

export default class AdvancedModeToggle extends Component {
  @service capabilities;

  get label() {
    return this.args.active
      ? "advanced_mode_toggle.simple_mode"
      : "advanced_mode_toggle.advanced_mode";
  }

  <template>
    <DButton
      class="btn-default advanced-mode-btn"
      @icon="gear"
      @label={{if this.capabilities.viewport.sm this.label}}
      @ariaLabel={{this.label}}
      @action={{@onToggle}}
      ...attributes
    />
  </template>
}
