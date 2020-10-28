import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

let userFound = false;

acceptance("Forgot password", function (needs) {
  needs.pretender((server, helper) => {
    server.post("/session/forgot_password", () => {
      return helper.response({
        user_found: userFound,
      });
    });
  });

  test("requesting password reset", async (assert) => {
    await visit("/");
    await click("header .login-button");
    await click("#forgot-password-link");

    assert.equal(
      find(".forgot-password-reset").attr("disabled"),
      "disabled",
      "it should disable the button until the field is filled"
    );

    await fillIn("#username-or-email", "someuser");
    await click(".forgot-password-reset");

    assert.equal(
      find(".alert-error").html().trim(),
      I18n.t("forgot_password.complete_username_not_found", {
        username: "someuser",
      }),
      "it should display an error for an invalid username"
    );

    await fillIn("#username-or-email", "someuser@gmail.com");
    await click(".forgot-password-reset");

    assert.equal(
      find(".alert-error").html().trim(),
      I18n.t("forgot_password.complete_email_not_found", {
        email: "someuser@gmail.com",
      }),
      "it should display an error for an invalid email"
    );

    await fillIn("#username-or-email", "someuser");

    userFound = true;

    await click(".forgot-password-reset");

    assert.notOk(
      exists(find(".alert-error")),
      "it should remove the flash error when succeeding"
    );

    assert.equal(
      find(".modal-body").html().trim(),
      I18n.t("forgot_password.complete_username_found", {
        username: "someuser",
      }),
      "it should display a success message for a valid username"
    );

    await visit("/");
    await click("header .login-button");
    await click("#forgot-password-link");
    await fillIn("#username-or-email", "someuser@gmail.com");
    await click(".forgot-password-reset");

    assert.equal(
      find(".modal-body").html().trim(),
      I18n.t("forgot_password.complete_email_found", {
        email: "someuser@gmail.com",
      }),
      "it should display a success message for a valid email"
    );
  });
});
