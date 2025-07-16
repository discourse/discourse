/* eslint-disable qunit/no-loose-assertions */
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, count } from "discourse/tests/helpers/qunit-helpers";
import { stubStripe } from "discourse/plugins/discourse-subscriptions/helpers/stripe";

acceptance("Subscriptions", function (needs) {
  needs.user();
  needs.hooks.beforeEach(function () {
    stubStripe();
  });

  test("viewing product page", async function (assert) {
    await visit("/s");

    assert.ok(count(".product-list") > 0, "has product page");
    assert.ok(count(".product:first-child a") > 0, "has a link");
  });
});
