import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import CreateCouponForm from "discourse/plugins/discourse-subscriptions/discourse/components/create-coupon-form";

module("Integration | Component | CreateCouponForm", function (hooks) {
  setupRenderingTest(hooks);

  test("creates a coupon from the entered values", async function (assert) {
    let created;
    const create = (params) => (created = params);
    const cancel = () => {};

    await render(
      <template>
        <CreateCouponForm @cancel={{cancel}} @create={{create}} />
      </template>
    );

    await fillIn("input[name='promo_code']", "SAVE10");
    await selectKit().expand();
    await selectKit().selectRowByValue("percent");
    await fillIn(".discount-amount", "10");
    await click("input[name='active']");
    await click(".btn-primary");

    assert.deepEqual(
      created,
      {
        promo: "SAVE10",
        discount_type: "percent",
        discount: "10",
        active: true,
      },
      "passes the form values to create"
    );
  });
});
