import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import dIcon from "discourse-common/helpers/d-icon";

export default class SignupProgressBar extends Component {
  @service siteSettings;
  @service site;
  @tracked steps = [];

  constructor() {
    super(...arguments);
    if (this.siteSettings.must_approve_users) {
      this.steps = ["signup", "activate", "approve", "login"];
    } else {
      this.steps = ["signup", "activate", "login"];
    }
  }

  get currentStepIndex() {
    return this.steps.findIndex((step) => step === this.args.step);
  }

  get lastStepIndex() {
    return this.steps.length - 1;
  }

  @action
  getStepState(index) {
    if (index === this.currentStepIndex) {
      return "active";
    } else if (index < this.currentStepIndex) {
      return "completed";
    } else if (index > this.currentStepIndex) {
      return "incomplete";
    }
  }

  <template>
    {{#if @step}}
      <div class="signup-progress-bar">
        {{#each this.steps as |step index|}}
          <div
            class={{concatClass
              "signup-progress-bar__segment"
              (concat "--" (this.getStepState index))
            }}
          >
            <div class="signup-progress-bar__step">
              <div class="signup-progress-bar__circle">
              </div>
            </div>
          </div>
        {{/each}}
      </div>
    {{/if}}
  </template>
}
