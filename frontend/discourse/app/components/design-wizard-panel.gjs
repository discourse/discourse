import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DesignWizardControls from "discourse/components/design-wizard/controls";
import { isTesting } from "discourse/lib/environment";
import { prefersReducedMotion } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";

export default class DesignWizardPanel extends Component {
  @service designWizard;

  element;

  @action
  registerElement(element) {
    this.element = element;
  }

  @action
  async close() {
    if (this.element && !isTesting() && !prefersReducedMotion()) {
      const slideOut =
        getComputedStyle(this.element)
          .getPropertyValue("--design-wizard-slide-out")
          .trim() || "translateX(100%)";

      await this.element
        .animate([{ transform: "translate(0, 0)" }, { transform: slideOut }], {
          duration: 250,
          easing: "ease-in",
          fill: "forwards",
        })
        .finished.catch(() => {});
    }

    this.designWizard.stop();
  }

  <template>
    {{#if this.designWizard.active}}
      <aside
        class="design-wizard
          {{unless this.designWizard.animateEntrance '--no-entrance'}}"
        aria-labelledby="design-wizard-title"
        {{didInsert this.registerElement}}
        ...attributes
      >
        <DButton
          @action={{this.close}}
          @icon="xmark"
          @title="modal.close"
          class="btn-transparent design-wizard__close"
        />
        <DesignWizardControls />
      </aside>
    {{/if}}
  </template>
}
