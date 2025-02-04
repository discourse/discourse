import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Controller | preferences/second-factor", function (hooks) {
  setupTest(hooks);

  test("displayOAuthWarning when OAuth login methods are enabled", function (assert) {
    const siteSettings = this.owner.lookup("service:site-settings");
    siteSettings.enable_google_oauth2_logins = true;

    const controller = this.owner.lookup(
      "controller:preferences/second-factor"
    );

    assert.true(controller.displayOAuthWarning);
  });
});
