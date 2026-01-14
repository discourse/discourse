import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import { stubStripe } from "discourse/plugins/discourse-subscriptions/helpers/stripe";

function singleProductPretender() {
  pretender.get("/s", () => {
    const products = [
      {
        id: "prod_23o8I7tU4g56",
        name: "Awesome Product",
        description:
          "Subscribe to our awesome product. For only $230.10 per month, you can get access. This is a test site. No real credit card transactions.",
      },
    ];

    return response(products);
  });
}

acceptance("Subscriptions", function (needs) {
  needs.user();
  needs.hooks.beforeEach(function () {
    stubStripe();
  });

  test("subscribing", async function (assert) {
    await visit("/s");
    await click(".product:first-child a");

    assert
      .dom(".discourse-subscriptions-section-columns")
      .exists("has the sections for billing");

    assert.dom(".subscribe-buttons button").exists("has buttons for subscribe");
  });

  test("skips products list on sites with one product", async function (assert) {
    singleProductPretender();

    await visit("/s");

    assert.dom(".subscribe-buttons button").exists({ count: 1 });
    assert.dom("input.subscribe-promo-code").exists();
    assert.dom("button.btn-payment").exists();
  });

  // In YAML `NO:` is a boolean, so we need quotes around `"NO":`.
  test("Norway is translated correctly", async function (assert) {
    assert.strictEqual(
      i18n("discourse_subscriptions.subscribe.countries.NO"),
      "Norway"
    );

    assert.strictEqual(
      i18n("discourse_subscriptions.subscribe.countries.NG"),
      "Nigeria"
    );
  });
});
