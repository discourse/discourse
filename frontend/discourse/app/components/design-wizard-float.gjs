import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DesignWizardPanel from "discourse/components/sidebar/design-wizard-panel";
import DButton from "discourse/ui-kit/d-button";

export default class DesignWizardFloat extends Component {
  @service designWizard;

  // the theme step is handled by the theme picker modal; the floating
  // panel takes over from the second step on
  get visible() {
    return this.designWizard.active && this.designWizard.stepIndex > 0;
  }

  @action
  close() {
    this.designWizard.stop();
  }

  <template>
    {{#if this.visible}}
      <div class="design-wizard-float">
        <DButton
          @action={{this.close}}
          @icon="xmark"
          @title="modal.close"
          class="btn-transparent design-wizard-float__close"
        />
        <DesignWizardPanel />
      </div>
    {{/if}}
  </template>
}
