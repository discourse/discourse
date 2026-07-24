import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { i18n } from "discourse-i18n";

module("Unit | Controller | subscriptions", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const siteSettings = this.owner.lookup("service:site-settings");
    siteSettings.discourse_subscriptions_pricing_table_enabled = true;
    siteSettings.discourse_subscriptions_pricing_table_id = "prctbl_123";
    siteSettings.discourse_subscriptions_public_key = "pk_test_123";

    this.currentUser = {
      checkEmail() {
        return Promise.resolve();
      },
    };
    this.owner.unregister("service:current-user");
    this.owner.register("service:current-user", this.currentUser, {
      instantiate: false,
    });
  });

  test("returns empty content while current user data loads", async function (assert) {
    this.currentUser.email = "user@example.com";
    this.currentUser.discourse_subscriptions_checkout_session_user_reference =
      "signed-reference";

    const controller = this.owner.lookup("controller:subscriptions");

    assert.strictEqual(controller.pricingTable, "");

    await settled();

    assert.true(
      String(controller.pricingTable).includes(
        'customer-email="user@example.com"'
      )
    );
  });

  test("returns empty content when current user reference is missing", async function (assert) {
    this.currentUser.email = "user@example.com";

    const controller = this.owner.lookup("controller:subscriptions");

    await settled();

    assert.strictEqual(controller.pricingTable, "");
  });

  test("returns no products when pricing table is not configured", function (assert) {
    const siteSettings = this.owner.lookup("service:site-settings");
    siteSettings.discourse_subscriptions_pricing_table_id = "";

    const controller = this.owner.lookup("controller:subscriptions");

    assert.strictEqual(
      controller.pricingTable,
      i18n("discourse_subscriptions.subscribe.no_products")
    );
  });
});
