import { acceptance } from "helpers/qunit-helpers";

let userFound = false;

acceptance("Login with email", {
  settings: {
    enable_local_logins_via_email: true,
    enable_facebook_logins: true
  },
  pretend(server, helper) {
    server.post("/u/email-login", () =>
      helper.response({ success: "OK", user_found: userFound })
    );
  }
});

QUnit.test("with email button", async assert => {
  await visit("/");
  await click("header .login-button");

  assert.ok(
    exists(".btn-social.facebook"),
    "it displays the facebook login button"
  );

  assert.ok(
    exists(".login-with-email-button"),
    "it displays the login with email button"
  );

  await fillIn("#login-account-name", "someuser");
  await click(".login-with-email-button");

  assert.equal(
    find(".alert-error").html(),
    I18n.t("email_login.complete_username_not_found", {
      username: "someuser"
    }),
    "it should display an error for an invalid username"
  );

  await fillIn("#login-account-name", "someuser@gmail.com");
  await click(".login-with-email-button");

  assert.equal(
    find(".alert-error").html(),
    I18n.t("email_login.complete_email_not_found", {
      email: "someuser@gmail.com"
    }),
    "it should display an error for an invalid email"
  );

  await fillIn("#login-account-name", "someuser");

  userFound = true;

  await click(".login-with-email-button");

  assert.equal(
    find(".alert-success")
      .html()
      .trim(),
    I18n.t("email_login.complete_username_found", { username: "someuser" }),
    "it should display a success message for a valid username"
  );

  await visit("/");
  await click("header .login-button");
  await fillIn("#login-account-name", "someuser@gmail.com");
  await click(".login-with-email-button");

  assert.equal(
    find(".alert-success")
      .html()
      .trim(),
    I18n.t("email_login.complete_email_found", {
      email: "someuser@gmail.com"
    }),
    "it should display a success message for a valid email"
  );

  userFound = false;
});
