import { acceptance } from "helpers/qunit-helpers";

let userFound = false;

acceptance("Login with email", {
  settings: {
    enable_local_logins_via_email: true,
    enable_facebook_logins: true
  },
  beforeEach() {
    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    // prettier-ignore
    server.post("/u/email-login", () => { // eslint-disable-line no-undef
      return response({ success: "OK", user_found: userFound });
    });
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

    assert.ok(
      exists(".login-with-email-button"),
      "it displays the login with email button"
    );
  });

  fillIn("#login-account-name", "someuser");
  click(".login-with-email-button");

  andThen(() => {
    assert.equal(
      find(".alert-error").html(),
      I18n.t("email_login.complete_username_not_found", {
        username: "someuser"
      }),
      "it should display an error for an invalid username"
    );
  });

  fillIn("#login-account-name", "someuser@gmail.com");
  click(".login-with-email-button");

  andThen(() => {
    assert.equal(
      find(".alert-error").html(),
      I18n.t("email_login.complete_email_not_found", {
        email: "someuser@gmail.com"
      }),
      "it should display an error for an invalid email"
    );
  });

  fillIn("#login-account-name", "someuser");

  andThen(() => {
    userFound = true;
  });

  click(".login-with-email-button");

  andThen(() => {
    assert.equal(
      find(".alert-success")
        .html()
        .trim(),
      I18n.t("email_login.complete_username_found", { username: "someuser" }),
      "it should display a success message for a valid username"
    );
  });

  visit("/");
  click("header .login-button");
  fillIn("#login-account-name", "someuser@gmail.com");
  click(".login-with-email-button");

  andThen(() => {
    assert.equal(
      find(".alert-success")
        .html()
        .trim(),
      I18n.t("email_login.complete_email_found", {
        email: "someuser@gmail.com"
      }),
      "it should display a success message for a valid email"
    );
  });

  andThen(() => {
    userFound = false;
  });
});
