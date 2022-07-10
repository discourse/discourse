import { module, test } from "qunit";
import { setupTest } from "ember-qunit";

module("Unit | Controller | preferences/second-factor", function (hooks) {
  setupTest(hooks);

  test("displayOAuthWarning when OAuth login methods are enabled", function (assert) {
    const controller = this.owner.lookup(
      "controller:preferences/second-factor"
    );
    controller.setProperties({
      siteSettings: {
        enable_google_oauth2_logins: true,
      },
    });

    assert.strictEqual(controller.displayOAuthWarning, true);
  });
});
