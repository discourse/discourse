import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

discourseModule("Unit | Controller | preferences/second-factor", function () {
  test("displayOAuthWarning when OAuth login methods are enabled", function (assert) {
    const controller = this.getController("preferences/second-factor", {
      siteSettings: {
        enable_google_oauth2_logins: true,
      },
    });
    assert.strictEqual(controller.get("displayOAuthWarning"), true);
  });
});
