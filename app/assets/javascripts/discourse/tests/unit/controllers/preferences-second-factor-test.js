import { moduleFor } from "ember-qunit";
import { test } from "qunit";
moduleFor("controller:preferences/second-factor");

test("displayOAuthWarning when OAuth login methods are enabled", function (assert) {
  const controller = this.subject({
    siteSettings: {
      enable_google_oauth2_logins: true,
    },
  });

  assert.equal(controller.get("displayOAuthWarning"), true);
});
