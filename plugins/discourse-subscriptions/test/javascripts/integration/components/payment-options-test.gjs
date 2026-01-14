import { tracked } from "@glimmer/tracking";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PaymentOptions from "discourse/plugins/discourse-subscriptions/discourse/components/payment-options";

module("Subscriptions | payment-options", function (hooks) {
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

    class State {
      @tracked selectedPlan;
    }

    const testState = new State();

    await render(
      <template>
        <PaymentOptions
          @plans={{plans}}
          @selectedPlan={{testState.selectedPlan}}
        />
      </template>
    );

    assert.dom(".btn-discourse-subscriptions-subscribe").exists({ count: 2 });

    assert.strictEqual(
      this.selectedPlan,
      undefined,
      "No plans are selected by default"
    );
  });
});
