import { tracked } from "@glimmer/tracking";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PaymentOptions from "discourse/plugins/discourse-subscriptions/discourse/components/payment-options";

module("payment-options", function (hooks) {
  setupRenderingTest(hooks);

  test("payment options have no plans", async function (assert) {
    await render(<template><PaymentOptions @plans={{false}} /></template>);

    assert
      .dom(".btn-discourse-subscriptions-subscribe")
      .doesNotExist("The plan buttons are not shown");
  });

  test("payment options has content", async function (assert) {
    const plans = [
      {
        currency: "aud",
        recurring: { interval: "year" },
        amountDollars: "44.99",
      },
      {
        currency: "gdp",
        recurring: { interval: "month" },
        amountDollars: "9.99",
      },
    ];

    const selectedPlan = tracked(undefined);

    await render(
      <template>
        <PaymentOptions @plans={{plans}} @selectedPlan={{selectedPlan.value}} />
      </template>
    );

    assert.dom(".btn-discourse-subscriptions-subscribe").exists({ count: 2 });

    assert.strictEqual(
      this.selectedPlan,
      undefined,
      "No plans are selected by default"
    );
  });
  test("selecting a plan reports it", async function (assert) {
    const plans = [
      { id: "plan_yearly", currency: "aud", unit_amount: 4499 },
      { id: "plan_monthly", currency: "aud", unit_amount: 999 },
    ];
    const selectedPlan = tracked(undefined);
    const selectPlan = (id) => (selectedPlan.value = id);

    await render(
      <template>
        <PaymentOptions
          @onSelectPlan={{selectPlan}}
          @plans={{plans}}
          @selectedPlan={{selectedPlan.value}}
        />
      </template>
    );

    await click(".btn-discourse-subscriptions-subscribe:last-child");

    assert.strictEqual(selectedPlan.value, "plan_yearly");
    assert
      .dom(".btn-discourse-subscriptions-subscribe:last-child")
      .hasClass("btn-primary", "highlights the selected plan");
    assert.deepEqual(
      plans.map((plan) => plan.id),
      ["plan_yearly", "plan_monthly"],
      "leaves the plans in their original order"
    );
  });
});
