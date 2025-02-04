import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Signing In", function () {
  test("sign in", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.dom(".login-modal").exists("shows the login modal");

    // Test that only username entry (not password) available on first step
    assert
      .dom("#login-account-name")
      .exists("should display username input on username step");
    assert
      .dom("#login-account-password")
      .doesNotExist("should not display password input on username step");

    // Test that invalid username gives error message
    await fillIn("#login-account-name", "thisisnotarealusername");
    await click(".d-modal__footer #login-button");
    assert
      .dom("#modal-alert")
      .exists("display login error for username with no account");

    // Test that password (and not username) shows on the second step
    await fillIn("#login-account-name", "eviltrout");
    await click(".d-modal__footer #login-button");
    assert
      .dom("#login-account-name")
      .doesNotExist("should not display username input on password step");
    assert
      .dom("#login-account-password")
      .exists("should display password input on password step");

    // Back button shows too, returns to username entry
    assert
      .dom("#login-back-to-username")
      .exists("back button is available on password step");
    await click("#login-back-to-username");
    assert
      .dom("#login-account-name")
      .exists("should display username input on username step after back");
    assert
      .dom("#login-account-password")
      .doesNotExist(
        "should not display password input on username step after back"
      );

    // Test invalid password
    await fillIn("#login-account-name", "eviltrout");
    await click(".d-modal__footer #login-button");
    await fillIn("#login-account-password", "incorrect");
    await click(".d-modal__footer #login-button");
    assert.dom("#modal-alert").exists("displays the login error");
    assert
      .dom(".d-modal__footer #login-button")
      .isEnabled("enables the login button");

    // Test password unmasking
    assert
      .dom("#login-account-password[type='password']")
      .exists("password is masked by default");
    await click(".toggle-password-mask");
    assert
      .dom("#login-account-password[type='text']")
      .exists("password is unmasked after toggle is clicked");

    // Use the correct password
    await fillIn("#login-account-password", "correct");
    await click(".d-modal__footer #login-button");
    assert
      .dom(".d-modal__footer #login-button")
      .isDisabled("disables the login button");
  });

  test("sign in - not activated", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.dom(".login-modal").exists("shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await click(".d-modal__footer #login-button");
    await fillIn("#login-account-password", "not-activated");
    await click(".d-modal__footer #login-button");
    assert
      .dom(".d-modal__body b")
      .hasText("<small>eviltrout@example.com</small>");
    assert
      .dom(".d-modal__body small")
      .doesNotExist("escapes the email address");

    await click(".d-modal__footer button.resend");
    assert
      .dom(".d-modal__body b")
      .hasText("<small>current@example.com</small>");
    assert
      .dom(".d-modal__body small")
      .doesNotExist("escapes the email address");
  });

  test("sign in - not activated - edit email", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.dom(".login-modal").exists("shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await click(".d-modal__footer #login-button");
    await fillIn("#login-account-password", "not-activated-edit");
    await click(".d-modal__footer #login-button");
    await click(".d-modal__footer button.edit-email");
    assert.dom(".activate-new-email").hasValue("current@example.com");
    assert.dom(".d-modal__footer .btn-primary").isDisabled("must change email");

    await fillIn(".activate-new-email", "different@example.com");
    assert.dom(".d-modal__footer .btn-primary").isNotDisabled();

    await click(".d-modal__footer .btn-primary");
    assert.dom(".d-modal__body b").hasText("different@example.com");
  });

  test("second factor", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.dom(".login-modal").exists("shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await click(".d-modal__footer #login-button");
    await fillIn("#login-account-password", "need-second-factor");
    await click(".d-modal__footer #login-button");

    assert
      .dom("#credentials")
      .isNotVisible("hides the username and password prompt");
    assert.dom("#second-factor").isVisible("displays the second factor prompt");
    assert
      .dom(".d-modal__footer #login-button")
      .isEnabled("enables the login button");

    await fillIn("#login-second-factor", "123456");
    await click(".d-modal__footer #login-button");

    assert
      .dom(".d-modal__footer .btn-primary")
      .isDisabled("disables the login button");
  });

  test("security key", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.dom(".login-modal").exists("shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await click(".d-modal__footer #login-button");
    await fillIn("#login-account-password", "need-security-key");
    await click(".d-modal__footer #login-button");

    assert
      .dom("#credentials")
      .isNotVisible("hides the username and password prompt");
    assert
      .dom("#login-second-factor")
      .isNotVisible("does not display the second factor prompt");
    assert.dom("#security-key").isVisible("shows the security key prompt");
    assert.dom("#login-button").isNotVisible("hides the login button");
  });

  test("second factor backup - valid token", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "eviltrout");
    await click(".d-modal__footer #login-button");
    await fillIn("#login-account-password", "need-second-factor");
    await click(".d-modal__footer #login-button");
    await click(".login-modal .toggle-second-factor-method");
    await fillIn("#login-second-factor", "123456");
    await click(".d-modal__footer #login-button");

    assert.dom(".d-modal__footer #login-button").isDisabled();
  });

  test("second factor backup - invalid token", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "eviltrout");
    await click(".d-modal__footer #login-button");
    await fillIn("#login-account-password", "need-second-factor");
    await click(".d-modal__footer #login-button");
    await click(".login-modal .toggle-second-factor-method");
    await fillIn("#login-second-factor", "something");
    await click(".d-modal__footer #login-button");

    assert
      .dom("#modal-alert")
      .exists("shows an error when the code is invalid");
  });
});
