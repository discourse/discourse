import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import RouteTemplate from "ember-route-template";
import getUrl from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import { defaultHomepage } from "discourse/lib/utilities";
import WizardCanvas from "discourse/static/wizard/components/wizard-canvas";
import WizardStep from "discourse/static/wizard/components/wizard-step";

export default RouteTemplate(
  class extends Component {
    @service router;
    @service siteSettings;

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

    #goHomeOrQuickStart() {
      if (this.siteSettings.bootstrap_mode_enabled) {
        DiscourseURL.routeTo(
          `/t/${this.siteSettings.admin_quick_start_topic_id}`
        );
      } else {
        this.router.transitionTo(`discovery.${defaultHomepage()}`);
      }
    }

    @action
    goNext(response) {
      const next = this.step.next;

      if (response?.refresh_required) {
        document.location = getUrl(`/wizard/steps/${next}`);
      } else if (response?.success && next) {
        this.router.transitionTo("wizard.step", next);
      } else if (response?.success) {
        this.#goHomeOrQuickStart();
      }
    }

    @action
    goBack() {
      this.router.transitionTo("wizard.step", this.step.previous);
    }

    @action
    goHome() {
      this.#goHomeOrQuickStart();
    }
  }
);
