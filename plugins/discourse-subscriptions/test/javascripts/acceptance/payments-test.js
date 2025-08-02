import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { stubStripe } from "discourse/plugins/discourse-subscriptions/helpers/stripe";

acceptance("Subscriptions", function (needs) {
  needs.user();
  needs.hooks.beforeEach(function () {
    stubStripe();
  });

  test("viewing product page", async function (assert) {
    await visit("/s");

    assert.dom(".product-list").exists("has product page");
    assert.dom(".product:first-child a").exists("has a link");
  });
});
