import Component from "@ember/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import formatCurrency from "../helpers/format-currency";

const RECURRING = "recurring";

@tagName("")
export default class PaymentPlan extends Component {
  @discourseComputed("selectedPlan")
  selectedClass(planId) {
    return planId === this.plan.id ? "btn-primary" : "";
  }

  @discourseComputed("plan.type")
  recurringPlan(type) {
    return type === RECURRING;
  }

  @action
  planClick() {
    this.clickPlan(this.plan);
    return false;
  }

  <template>
    <DButton
      @action={{this.planClick}}
      class={{concatClass
        "btn-discourse-subscriptions-subscribe"
        this.selectedClass
      }}
    >
      <span class="interval">
        {{#if this.recurringPlan}}
          {{i18n
            (concat
              "discourse_subscriptions.plans.interval.adverb."
              this.plan.recurring.interval
            )
          }}
        {{else}}
          {{i18n "discourse_subscriptions.one_time_payment"}}
        {{/if}}
      </span>

      <span class="amount">
        {{formatCurrency this.plan.currency this.plan.amountDollars}}
      </span>
    </DButton>
  </template>
}
