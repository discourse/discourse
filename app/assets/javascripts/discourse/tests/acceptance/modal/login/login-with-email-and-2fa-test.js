import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const TOKEN = "sometoken";

acceptance("Login with email and 2FA", function (needs) {
  needs.settings({
    enable_local_logins_via_email: true,
  });

  needs.pretender((server, helper) => {
    server.post("/u/email-login", () =>
      helper.response({
        success: "OK",
        user_found: true,
      })
    );

    server.get(`/session/email-login/${TOKEN}.json`, () =>
      helper.response({
        token: TOKEN,
        can_login: true,
        token_email: "blah@example.com",
        security_key_required: true,
        second_factor_required: true,
      })
    );
  });

  test("You can switch from security key to 2FA", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "blah@example.com");
    await click("#email-login-link");
    await visit(`/session/email-login/${TOKEN}`);
    await click(".toggle-second-factor-method");

    assert.dom("#second-factor").containsText(i18n("user.second_factor.title"));
  });
});
