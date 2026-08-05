import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { logOnboardingEvent } from "discourse/lib/admin-onboarding";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class OnboardingStep extends Component {
  static name() {
    throw new Error("Name is required for OnboardingStep");
  }

  @service keyValueStore;
  @service appEvents;

  @tracked
  completed = this.keyValueStore.get(`onboarding_step_${this.name}`) || false;

  i18nKey = "admin_onboarding_banner.";

  get name() {
    return this.constructor.name;
  }

  get checkboxIcon() {
    return this.completed ? "circle-check" : "far-circle";
  }

  get buttonLabel() {
    return this.completed
      ? `admin_onboarding_banner.${this.name}.completed`
      : `admin_onboarding_banner.${this.name}.action`;
  }

  @action
  performAction() {
    throw new Error("performAction is required for OnboardingStep");
  }

  // Awaits the audit write so callers that reload the page on completion can't
  // cancel it in flight.
  async markAsCompleted() {
    // app events backing some steps can fire more than once, so only audit the
    // first transition into the completed state
    const alreadyCompleted = this.completed;

    this.keyValueStore.set({
      key: `onboarding_step_${this.name}`,
      value: true,
    });
    this.completed = true;
    this.appEvents.trigger(`onboarding-step:completed`, this.name);

    if (!alreadyCompleted) {
      await logOnboardingEvent("step_completed", this.name);
    }

    return this.args.onCompleted?.(this.name);
  }

  <template>
    <div class="onboarding-step" id={{this.name}}>
      <div class="onboarding-step__checkbox">
        {{~dIcon
          this.checkboxIcon
          class=(dConcatClass
            "onboarding-step__checkbox-icon" (if this.completed "--completed")
          )
        }}
        <span class="onboarding-step__title">{{i18n
            (concat this.i18nKey this.name ".title")
          }}</span>

      </div>

      <div class="onboarding-step__description">
        {{i18n (concat this.i18nKey this.name ".description")}}
      </div>
      <div class="onboarding-step__action">
        <DButton
          @label={{this.buttonLabel}}
          @action={{this.performAction}}
          class={{dConcatClass
            "btn-transparent btn-small btn-link"
            (if this.completed "--completed")
          }}
        />

      </div>
    </div>
  </template>
}
