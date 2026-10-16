import Component from "@glimmer/component";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import PaymentPlan from "./payment-plan.gjs";

export default class PaymentOptions extends Component {
  get orderedPlans() {
    if (this.args.plans) {
      return this.args.plans.toSorted((a, b) =>
        a.unit_amount > b.unit_amount ? 1 : -1
      );
    }
  }

  @action
  clickPlan(plan) {
    this.args.onSelectPlan(plan.id);
  }

  <template>
    <div ...attributes>
      <p>
        {{i18n "discourse_subscriptions.plans.select"}}
      </p>

      <div class="subscribe-buttons">
        {{#each this.orderedPlans as |plan|}}
          <PaymentPlan
            @clickPlan={{this.clickPlan}}
            @plan={{plan}}
            @selectedPlan={{@selectedPlan}}
          />
        {{/each}}
      </div>
    </div>
  </template>
}
