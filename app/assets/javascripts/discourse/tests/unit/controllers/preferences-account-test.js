import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

discourseModule("Unit | Controller | preferences/account", function () {
  test("updating of associated accounts", function (assert) {
    const controller = this.getController("preferences/account", {
      siteSettings: {
        enable_google_oauth2_logins: true,
      },
      model: {
        id: 70,
        second_factor_enabled: true,
        is_anonymous: true,
      },
      currentUser: {
        id: 1234,
      },
      site: {
        isMobileDevice: false,
      },
    });

    assert.strictEqual(controller.get("canUpdateAssociatedAccounts"), false);

    controller.set("model.second_factor_enabled", false);
    assert.strictEqual(controller.get("canUpdateAssociatedAccounts"), false);

    controller.set("model.is_anonymous", false);
    assert.strictEqual(controller.get("canUpdateAssociatedAccounts"), false);

    controller.set("model.id", 1234);
    assert.strictEqual(controller.get("canUpdateAssociatedAccounts"), true);
  });
});
