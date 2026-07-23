import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DesignWizardPanel from "discourse/components/sidebar/design-wizard-panel";
import DButton from "discourse/ui-kit/d-button";

export default class DesignWizardFloat extends Component {
  @service designWizard;

  @action
  close() {
    this.designWizard.stop();
  }

  <template>
    {{#if this.designWizard.active}}
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
