import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import DButton from "discourse/ui-kit/d-button";
import CapabilitiesService from "discourse/services/capabilities";

export default class AdvancedModeToggle extends Component {
  @service(() => CapabilitiesService) capabilities;

  get label() {
    return this.args.active
      ? "advanced_mode_toggle.simple_mode"
      : "advanced_mode_toggle.advanced_mode";
  }

  <template>
    <DButton
      class="btn-default advanced-mode-btn"
      ...attributes
      @action={{@onToggle}}
      @ariaLabel={{this.label}}
      @icon="gear"
      @label={{if this.capabilities.viewport.sm this.label}}
    />
  </template>
}
