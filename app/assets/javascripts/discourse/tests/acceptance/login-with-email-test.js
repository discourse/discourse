import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import I18n from "I18n";
import { test } from "qunit";

acceptance("Login with email", function (needs) {
  needs.settings({
    enable_local_logins_via_email: true,
    enable_facebook_logins: true,
  });

  let userFound = false;
  needs.pretender((server, helper) => {
    server.post("/u/email-login", () =>
      helper.response({ success: "OK", user_found: userFound })
    );
  });

  test("with email button", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.ok(
      exists(".btn-social.facebook"),
      "it displays the facebook login button"
    );

    assert.ok(
      exists("#email-login-link"),
      "it displays the login with email button"
    );

    await fillIn("#login-account-name", "someuser");
    await click("#email-login-link");

    assert.strictEqual(
      queryAll(".alert-error").html(),
      I18n.t("email_login.complete_username_not_found", {
        username: "someuser",
      }),
      "it should display an error for an invalid username"
    );

    await fillIn("#login-account-name", "someuser@gmail.com");
    await click("#email-login-link");

    assert.strictEqual(
      queryAll(".alert-error").html(),
      I18n.t("email_login.complete_email_not_found", {
        email: "someuser@gmail.com",
      }),
      "it should display an error for an invalid email"
    );

    await fillIn("#login-account-name", "someuser");

    userFound = true;

    await click("#email-login-link");

    assert.strictEqual(
      queryAll(".alert-success").html().trim(),
      I18n.t("email_login.complete_username_found", { username: "someuser" }),
      "it should display a success message for a valid username"
    );

    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "someuser@gmail.com");
    await click("#email-login-link");

    assert.strictEqual(
      queryAll(".alert-success").html().trim(),
      I18n.t("email_login.complete_email_found", {
        email: "someuser@gmail.com",
      }),
      "it should display a success message for a valid email"
    );

    userFound = false;
  });
});
