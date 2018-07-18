import { acceptance } from "helpers/qunit-helpers";

let userFound = false;

acceptance("Forgot password", {
  beforeEach() {
    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    // prettier-ignore
    server.post("/session/forgot_password", () => { // eslint-disable-line no-undef
      return response({ user_found: userFound });
    });
  }
});

QUnit.test("requesting password reset", assert => {
  visit("/");
  click("header .login-button");
  click("#forgot-password-link");

  andThen(() => {
    assert.equal(
      find(".forgot-password-reset").attr("disabled"),
      "disabled",
      "it should disable the button until the field is filled"
    );
  });

  fillIn("#username-or-email", "someuser");
  click(".forgot-password-reset");

  andThen(() => {
    assert.equal(
      find(".alert-error")
        .html()
        .trim(),
      I18n.t("forgot_password.complete_username_not_found", {
        username: "someuser"
      }),
      "it should display an error for an invalid username"
    );
  });

  fillIn("#username-or-email", "someuser@gmail.com");
  click(".forgot-password-reset");

  andThen(() => {
    assert.equal(
      find(".alert-error")
        .html()
        .trim(),
      I18n.t("forgot_password.complete_email_not_found", {
        email: "someuser@gmail.com"
      }),
      "it should display an error for an invalid email"
    );
  });

  fillIn("#username-or-email", "someuser");

  andThen(() => {
    userFound = true;
  });

  click(".forgot-password-reset");

  andThen(() => {
    assert.notOk(
      exists(find(".alert-error")),
      "it should remove the flash error when succeeding"
    );

    assert.equal(
      find(".modal-body")
        .html()
        .trim(),
      I18n.t("forgot_password.complete_username_found", {
        username: "someuser"
      }),
      "it should display a success message for a valid username"
    );
  });

  visit("/");
  click("header .login-button");
  click("#forgot-password-link");
  fillIn("#username-or-email", "someuser@gmail.com");
  click(".forgot-password-reset");

  andThen(() => {
    assert.equal(
      find(".modal-body")
        .html()
        .trim(),
      I18n.t("forgot_password.complete_email_found", {
        email: "someuser@gmail.com"
      }),
      "it should display a success message for a valid email"
    );
  });
});
