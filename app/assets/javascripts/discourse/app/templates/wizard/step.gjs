import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import RouteTemplate from "ember-route-template";
import WizardCanvas from "discourse/static/wizard/components/wizard-canvas";
import WizardStep from "discourse/static/wizard/components/wizard-step";
import getUrl from "discourse-common/lib/get-url";

export default RouteTemplate(
  class extends Component {
    @service router;

    <template>
      {{#if this.showCanvas}}
        <WizardCanvas />
      {{/if}}

      <WizardStep
        @step={{@model.step}}
        @wizard={{@model.wizard}}
        @goNext={{this.goNext}}
        @goBack={{this.goBack}}
        @goHome={{this.goHome}}
      />
    </template>

    get step() {
      return this.args.model.step;
    }

    get showCanvas() {
      return this.step.id === "ready";
    }

    @action
    goNext(response) {
      const next = this.step.next;

      if (response?.refresh_required) {
        document.location = getUrl(`/wizard/steps/${next}`);
      } else if (response?.success && next) {
        this.router.transitionTo("wizard.step", next);
      } else if (response?.success) {
        this.router.transitionTo("discovery.latest");
      }
    }

    @action
    goBack() {
      this.router.transitionTo("wizard.step", this.step.previous);
    }

    @action
    goHome() {
      this.router.transitionTo("discovery.latest");
    }
  }
);
