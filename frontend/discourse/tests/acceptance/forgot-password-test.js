import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

let userFound = false;

acceptance("Forgot password", function (needs) {
  needs.pretender((server, helper) => {
    needs.settings({
      hide_email_address_taken: false,
    });

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
      i18n("forgot_password.complete_username_not_found", {
        username: "someuser",
      }),
      "displays an error for an invalid username"
    );

    await fillIn("#username-or-email", "someuser@gmail.com");
    await click(".forgot-password-reset");

    assert.dom(".alert-error").hasHtml(
      i18n("forgot_password.complete_email_not_found", {
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
      i18n("forgot_password.complete_username_found", {
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
      i18n("forgot_password.complete_email_found", {
        email: "someuser@gmail.com",
      }),
      "displays a success message for a valid email"
    );
  });
});

acceptance(
  "Forgot password - hide_email_address_taken enabled",
  function (needs) {
    needs.settings({
      hide_email_address_taken: true,
    });

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

      await fillIn("#username-or-email", "someuser@discourse.org");
      await click(".forgot-password-reset");

      assert.dom(".d-modal__body").hasHtml(
        i18n("forgot_password.complete_email", {
          email: "someuser@discourse.org",
        }),
        "displays a success message"
      );
    });
  }
);

acceptance("Forgot password - email codes", function (needs) {
  needs.settings({ hide_email_address_taken: false });

  needs.pretender((server, helper) => {
    server.post("/session/forgot_password", () =>
      helper.response({ success: "OK", email_code: true, user_found: true })
    );
    server.post("/session/password-reset-code/verify", () =>
      helper.response({ error: i18n("email_login_code.invalid_code") })
    );
  });

  test("verifies a reset code and lets the user change the account", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await click("#forgot-password-link");
    await fillIn("#username-or-email", "someuser");
    await click(".forgot-password-reset");

    assert.dom(".d-otp-input").exists("the modal requests a verification code");
    assert
      .dom(".code-login-form__instructions")
      .hasText(
        i18n("forgot_password.code_instructions"),
        "shows reset instructions"
      );
    assert
      .dom(".forgot-password-reset")
      .doesNotExist("hides the request button");

    await fillIn(".d-otp-input", "000000");

    assert
      .dom(".code-login-form__error")
      .hasText(
        i18n("email_login_code.invalid_code"),
        "shows the verification error"
      );
    assert.dom(".d-otp-input").hasValue("", "allows another attempt");

    pretender.post("/session/forgot_password", (request) => {
      assert.strictEqual(
        new URLSearchParams(request.requestBody).get("login"),
        "someuser",
        "resends the reset code for the same account"
      );
      return response({ success: "OK", email_code: true, user_found: true });
    });
    await click(".code-login-form__resend");

    assert
      .dom(".code-login-form__notice")
      .hasText(i18n("code_login.code_resent"), "confirms the code was resent");

    await click(".code-login-form__change-email");

    assert
      .dom("#username-or-email")
      .hasValue("someuser", "returns to account lookup");
    assert.dom(".forgot-password-reset").exists("can request another code");
  });

  test("opens the password reset page after redeeming a code", async function (assert) {
    const redirect = sinon.stub(DiscourseURL, "redirectTo");
    pretender.post("/session/password-reset-code/verify", (request) => {
      assert.strictEqual(
        new URLSearchParams(request.requestBody).get("code"),
        "123456",
        "submits the entered code"
      );
      return response({
        success: "OK",
        redirect_url: "/u/password-reset/reset-token",
      });
    });

    await visit("/");
    await click("header .login-button");
    await click("#forgot-password-link");
    await fillIn("#username-or-email", "someuser");
    await click(".forgot-password-reset");
    await fillIn(".d-otp-input", "123456");

    assert.true(
      redirect.calledOnceWithExactly("/u/password-reset/reset-token"),
      "loads the reset page returned by the server"
    );
  });

  test("shows code entry when account existence is hidden", async function (assert) {
    this.siteSettings.hide_email_address_taken = true;
    pretender.post("/session/forgot_password", () =>
      response({ success: "OK", email_code: true })
    );

    await visit("/");
    await click("header .login-button");
    await click("#forgot-password-link");
    await fillIn("#username-or-email", "unknown@example.com");
    await click(".forgot-password-reset");

    assert
      .dom(".d-otp-input")
      .exists("shows code entry without disclosing account existence");
  });
});
