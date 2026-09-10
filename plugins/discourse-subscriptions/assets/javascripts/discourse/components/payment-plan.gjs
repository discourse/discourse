import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import formatCurrency from "../helpers/format-currency";

const RECURRING = "recurring";

export default class PaymentPlan extends Component {
  get selectedClass() {
    return this.args.selectedPlan === this.args.plan.id ? "btn-primary" : "";
  }

  get recurringPlan() {
    return this.args.plan?.type === RECURRING;
  }

  @action
  planClick() {
    this.args.clickPlan(this.args.plan);
    return false;
  }

  <template>
    <DButton
      class={{dConcatClass
        "btn-discourse-subscriptions-subscribe"
        this.selectedClass
      }}
      @action={{@planClick}}
    >
      <span class="interval">
        {{#if this.recurringPlan}}
          {{i18n
            (concat
              "discourse_subscriptions.plans.interval.adverb."
              @plan.recurring.interval
            )
          }}
        {{else}}
          {{i18n "discourse_subscriptions.one_time_payment"}}
        {{/if}}
      </span>

      <span class="amount">
        {{formatCurrency @plan.currency @plan.amountDollars}}
      </span>
    </DButton>
  </template>
}
