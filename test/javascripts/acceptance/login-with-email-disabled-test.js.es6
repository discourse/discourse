import { acceptance } from "helpers/qunit-helpers";

acceptance("Login with email disabled", {
  settings: {
    enable_local_logins_via_email: false,
    enable_facebook_logins: true
  }
});

QUnit.test("with email button", assert => {
  visit("/");
  click("header .login-button");

  andThen(() => {
    assert.ok(
      exists(".btn-social.facebook"),
      "it displays the facebook login button"
    );

    assert.notOk(
      exists(".login-with-email-button"),
      "it displays the login with email button"
    );
  });
});
