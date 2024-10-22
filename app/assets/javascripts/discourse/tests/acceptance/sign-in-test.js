import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Signing In", function () {
  test("sign in", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.ok(exists(".login-modal"), "it shows the login modal");

    // Test invalid password first
    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "incorrect");
    await click(".d-modal__footer .btn-primary");
    assert.ok(exists("#modal-alert:visible"), "it displays the login error");
    assert
      .dom(".d-modal__footer .btn-primary:disabled")
      .doesNotExist("enables the login button");

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
    await click(".d-modal__footer .btn-primary");
    assert
      .dom(".d-modal__footer .btn-primary:disabled")
      .exists("disables the login button");
  });

  test("sign in - not activated", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.ok(exists(".login-modal"), "it shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "not-activated");
    await click(".d-modal__footer .btn-primary");
    assert
      .dom(".d-modal__body b")
      .hasText("<small>eviltrout@example.com</small>");
    assert.ok(!exists(".d-modal__body small"), "it escapes the email address");

    await click(".d-modal__footer button.resend");
    assert
      .dom(".d-modal__body b")
      .hasText("<small>current@example.com</small>");
    assert.ok(!exists(".d-modal__body small"), "it escapes the email address");
  });

  test("sign in - not activated - edit email", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.dom(".login-modal").exists("it shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "not-activated-edit");
    await click(".d-modal__footer .btn-primary");
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

    assert.ok(exists(".login-modal"), "it shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "need-second-factor");
    await click(".d-modal__footer .btn-primary");

    assert
      .dom("#credentials:visible")
      .doesNotExist("it hides the username and password prompt");
    assert
      .dom("#second-factor:visible")
      .exists("it displays the second factor prompt");
    assert
      .dom(".d-modal__footer .btn-primary:disabled")
      .doesNotExist("enables the login button");

    await fillIn("#login-second-factor", "123456");
    await click(".d-modal__footer .btn-primary");

    assert
      .dom(".d-modal__footer .btn-primary:disabled")
      .exists("disables the login button");
  });

  test("security key", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.ok(exists(".login-modal"), "it shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "need-security-key");
    await click(".d-modal__footer .btn-primary");

    assert
      .dom("#credentials:visible")
      .doesNotExist("it hides the username and password prompt");
    assert
      .dom("#login-second-factor:visible")
      .doesNotExist("it does not display the second factor prompt");
    assert
      .dom("#security-key:visible")
      .exists("it shows the security key prompt");
    assert.notOk(exists("#login-button:visible"), "hides the login button");
  });

  test("second factor backup - valid token", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "need-second-factor");
    await click(".d-modal__footer .btn-primary");
    await click(".login-modal .toggle-second-factor-method");
    await fillIn("#login-second-factor", "123456");
    await click(".d-modal__footer .btn-primary");

    assert
      .dom(".d-modal__footer .btn-primary:disabled")
      .exists("it closes the modal when the code is valid");
  });

  test("second factor backup - invalid token", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "need-second-factor");
    await click(".d-modal__footer .btn-primary");
    await click(".login-modal .toggle-second-factor-method");
    await fillIn("#login-second-factor", "something");
    await click(".d-modal__footer .btn-primary");

    assert
      .dom("#modal-alert:visible")
      .exists("it shows an error when the code is invalid");
  });
});
