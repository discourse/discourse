import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

const TOKEN = "sometoken";

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

    server.get(`/session/email-login/${TOKEN}.json`, () =>
      helper.response({
        token: TOKEN,
        can_login: true,
        token_email: "blah@example.com",
      })
    );

    server.post(`/session/email-login/${TOKEN}`, () =>
      helper.response({
        success: true,
      })
    );
  });

  test("with email button", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert
      .dom(".btn-social.facebook")
      .exists("it displays the facebook login button");

    assert
      .dom("#email-login-link")
      .exists("it displays the login with email button");

    await fillIn("#login-account-name", "someuser");
    await click("#email-login-link");

    assert.dom("#modal-alert").hasHtml(
      I18n.t("email_login.complete_username_not_found", {
        username: "someuser",
      }),
      "displays an error for an invalid username"
    );

    await fillIn("#login-account-name", "someuser@gmail.com");
    await click("#email-login-link");

    assert.dom("#modal-alert").hasHtml(
      I18n.t("email_login.complete_email_not_found", {
        email: "someuser@gmail.com",
      }),
      "displays an error for an invalid email"
    );

    await fillIn("#login-account-name", "someuser");

    userFound = true;

    await click("#email-login-link");

    assert
      .dom(".alert-success")
      .hasHtml(
        I18n.t("email_login.complete_username_found", { username: "someuser" }),
        "displays a success message for a valid username"
      );

    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "someuser@gmail.com");
    await click("#email-login-link");

    assert.dom(".alert-success").hasHtml(
      I18n.t("email_login.complete_email_found", {
        email: "someuser@gmail.com",
      }),
      "displays a success message for a valid email"
    );

    userFound = false;
  });

  test("finish login UI", async function (assert) {
    await visit(`/session/email-login/${TOKEN}`);
    sinon.stub(DiscourseURL, "redirectTo");
    await click(".email-login .btn-primary");
    assert.true(DiscourseURL.redirectTo.calledWith("/"), "redirects to home");
  });

  test("finish login UI - safe mode", async function (assert) {
    await visit(`/session/email-login/${TOKEN}?safe_mode=no_themes,no_plugins`);
    sinon.stub(DiscourseURL, "redirectTo");
    await click(".email-login .btn-primary");
    assert.true(
      DiscourseURL.redirectTo.calledWith("/?safe_mode=no_themes%2Cno_plugins"),
      "redirects to home with safe mode"
    );
  });
});
