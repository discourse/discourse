import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
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

  get icon() {
    throw new Error("Icon is required for OnboardingStep");
  }

  @action
  performAction() {
    throw new Error("performAction is required for OnboardingStep");
  }

  markAsCompleted() {
    this.keyValueStore.set({
      key: `onboarding_step_${this.name}`,
      value: true,
    });
    this.completed = true;
    this.appEvents.trigger(`onboarding-step:completed`, this.name);
  }

  <template>
    <div class="onboarding-step" id={{this.name}}>
      <div class="onboarding-step__checkbox">
        <span
          class={{if
            this.completed
            "chcklst-box checked fa fa-square-check-o"
            "chcklst-box fa fa-square-o"
          }}
        />
        <span>{{i18n (concat this.i18nKey this.name ".title")}}</span>
      </div>

      <div class="onboarding-step__description">
        <span>
          {{i18n (concat this.i18nKey this.name ".description")}}
        </span>
      </div>

      <div class="onboarding-step__action">
        <DButton
          @icon={{this.icon}}
          @label={{concat this.i18nKey this.name ".action"}}
          @action={{this.performAction}}
          class="btn btn-default"
        />
      </div>
    </div>
  </template>
}
