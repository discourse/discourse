import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Controller | preferences/account", function (hooks) {
  setupTest(hooks);

  test("updating of associated accounts", function (assert) {
    const siteSettings = this.owner.lookup("service:site-settings");
    siteSettings.enable_google_oauth2_logins = true;

    const site = this.owner.lookup("service:site");
    site.set("isMobileDevice", false);

    const controller = this.owner.lookup("controller:preferences/account");
    controller.setProperties({
      model: {
        id: 70,
        second_factor_enabled: true,
        is_anonymous: true,
      },
      currentUser: {
        id: 1234,
      },
    });

    assert.false(controller.canUpdateAssociatedAccounts);

    controller.set("model.second_factor_enabled", false);
    assert.false(controller.canUpdateAssociatedAccounts);

    controller.set("model.is_anonymous", false);
    assert.false(controller.canUpdateAssociatedAccounts);

    controller.set("model.id", 1234);
    assert.true(controller.canUpdateAssociatedAccounts);
  });
});
