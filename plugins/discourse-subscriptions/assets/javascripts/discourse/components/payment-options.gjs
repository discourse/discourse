/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { i18n } from "discourse-i18n";
import PaymentPlan from "./payment-plan";

export default class PaymentOptions extends Component {
  @computed("plans")
  get orderedPlans() {
    if (this.plans) {
      return this.plans.sort((a, b) => (a.unit_amount > b.unit_amount ? 1 : -1));
    }
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    if (this.plans && this.plans.length === 1) {
      this.set("selectedPlan", this.plans[0].id);
    }
  }

  @action
  clickPlan(plan) {
    this.set("selectedPlan", plan.id);
  }

  <template>
    <p>
      {{i18n "discourse_subscriptions.plans.select"}}
    </p>

    <div class="subscribe-buttons">
      {{#each this.orderedPlans as |plan|}}
        <PaymentPlan
          @plan={{plan}}
          @selectedPlan={{this.selectedPlan}}
          @clickPlan={{this.clickPlan}}
        />
      {{/each}}
    </div>
  </template>
}
