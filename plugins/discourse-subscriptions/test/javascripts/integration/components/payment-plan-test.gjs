import { tracked } from "@glimmer/tracking";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PaymentPlan from "discourse/plugins/discourse-subscriptions/discourse/components/payment-plan";

module("Subscriptions | payment-plan", function (hooks) {
  setupRenderingTest(hooks);

  test("Payment plan subscription button rendered", async function (assert) {
    const plan = {
      type: "recurring",
      currency: "aud",
      recurring: { interval: "year" },
      amountDollars: "44.99",
    };
    let selectedPlan;

    await render(
      <template>
        <PaymentPlan @plan={{plan}} @selectedPlan={{selectedPlan}} />
      </template>
    );

    assert
      .dom(".btn-discourse-subscriptions-subscribe")
      .exists("The payment button is shown");

    assert
      .dom(".btn-discourse-subscriptions-subscribe:first-child .interval")
      .hasText("Yearly", "The plan interval is shown -- Yearly");

    assert
      .dom(".btn-discourse-subscriptions-subscribe:first-child .amount")
      .hasText("$44.99", "The plan amount and currency is shown");
  });

  test("Payment plan one-time-payment button rendered", async function (assert) {
    const plan = {
      type: "one_time",
      currency: "USD",
      amountDollars: "3.99",
    };

    class State {
      @tracked selectedPlan;
    }

    const testState = new State();

    await render(
      <template>
        <PaymentPlan @plan={{plan}} @selectedPlan={{testState.selectedPlan}} />
      </template>
    );

    assert
      .dom(".btn-discourse-subscriptions-subscribe:first-child .interval")
      .hasText("One-Time Payment", "Shown as one time payment");
  });
});
