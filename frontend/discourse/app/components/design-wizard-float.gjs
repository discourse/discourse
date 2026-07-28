import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DesignWizardPanel from "discourse/components/sidebar/design-wizard-panel";
import { isTesting } from "discourse/lib/environment";
import { prefersReducedMotion } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";

export default class DesignWizardFloat extends Component {
  @service designWizard;

  element;

  @action
  registerElement(element) {
    this.element = element;
  }

  @action
  async close() {
    if (this.element && !isTesting() && !prefersReducedMotion()) {
      await this.element
        .animate(
          [{ transform: "translateX(0)" }, { transform: "translateX(100%)" }],
          { duration: 250, easing: "ease-in", fill: "forwards" }
        )
        .finished.catch(() => {});
    }

    this.designWizard.stop();
  }

  <template>
    {{#if this.designWizard.active}}
      <div
        class="design-wizard-float
          {{unless this.designWizard.animateEntrance '--no-entrance'}}"
        {{didInsert this.registerElement}}
      >
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
