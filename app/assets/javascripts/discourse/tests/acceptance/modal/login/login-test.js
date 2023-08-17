import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { click, fillIn, tab, visit } from "@ember/test-helpers";
import I18n from "I18n";

acceptance("Modal - Login", function () {
  test("You can tab to the login button", async function (assert) {
    await visit("/");
    await click("header .login-button");
    // you have to press the tab key twice to get to the login button
    await tab({ unRestrainTabIndex: true });
    await tab({ unRestrainTabIndex: true });
    assert.dom(".modal-footer #login-button").isFocused();
  });
});

acceptance("Modal - Login - With 2FA", function (needs) {
  needs.settings({
    enable_local_logins_via_email: true,
  });

  needs.pretender((server, helper) => {
    server.post(`/session`, () =>
      helper.response({
        error: I18n.t("login.invalid_second_factor_code"),
        multiple_second_factor_methods: false,
        security_key_enabled: false,
        totp_enabled: true,
      })
    );
  });

  test("You can tab to 2FA login button", async function (assert) {
    await visit("/");
    await click("header .login-button");

    await fillIn("#login-account-name", "isaac@discourse.org");
    await fillIn("#login-account-password", "password");
    await click("#login-button");

    assert.dom("#login-second-factor").isFocused();
    await tab();
    assert.dom("#login-button").isFocused();
  });
});
