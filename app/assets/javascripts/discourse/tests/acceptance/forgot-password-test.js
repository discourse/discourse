import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

let userFound = false;

acceptance("Forgot password", function (needs) {
  needs.pretender((server, helper) => {
    server.post("/session/forgot_password", () => {
      return helper.response({
        user_found: userFound,
      });
    });
  });

  test("requesting password reset", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await click("#forgot-password-link");

    assert
      .dom(".forgot-password-reset")
      .isDisabled("disables the button until the field is filled");

    await fillIn("#username-or-email", "someuser");
    await click(".forgot-password-reset");

    assert.dom(".alert-error").hasHtml(
      I18n.t("forgot_password.complete_username_not_found", {
        username: "someuser",
      }),
      "displays an error for an invalid username"
    );

    await fillIn("#username-or-email", "someuser@gmail.com");
    await click(".forgot-password-reset");

    assert.dom(".alert-error").hasHtml(
      I18n.t("forgot_password.complete_email_not_found", {
        email: "someuser@gmail.com",
      }),
      "displays an error for an invalid email"
    );

    await fillIn("#username-or-email", "someuser");

    userFound = true;

    await click(".forgot-password-reset");

    assert
      .dom(".alert-error")
      .doesNotExist("it should remove the flash error when succeeding");

    assert.dom(".d-modal__body").hasHtml(
      I18n.t("forgot_password.complete_username_found", {
        username: "someuser",
      }),
      "displays a success message for a valid username"
    );

    await visit("/");
    await click("header .login-button");
    await click("#forgot-password-link");
    await fillIn("#username-or-email", "someuser@gmail.com");
    await click(".forgot-password-reset");

    assert.dom(".d-modal__body").hasHtml(
      I18n.t("forgot_password.complete_email_found", {
        email: "someuser@gmail.com",
      }),
      "displays a success message for a valid email"
    );
  });
});

acceptance(
  "Forgot password - hide_email_address_taken enabled",
  function (needs) {
    needs.pretender((server, helper) => {
      server.post("/session/forgot_password", () => {
        return helper.response({});
      });
    });

    test("requesting password reset", async function (assert) {
      await visit("/");
      await click("header .login-button");
      await click("#forgot-password-link");

      assert
        .dom(".forgot-password-reset")
        .isDisabled("disables the button until the field is filled");

      await fillIn("#username-or-email", "someuser");
      await click(".forgot-password-reset");

      assert.dom(".d-modal__body").hasHtml(
        I18n.t("forgot_password.complete_username", {
          username: "someuser",
        }),
        "displays a success message"
      );
    });
  }
);
