import {
  acceptance,
  count,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Signing In", function () {
  test("sign in", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.ok(exists(".login-modal"), "it shows the login modal");

    // Test invalid password first
    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "incorrect");
    await click(".modal-footer .btn-primary");
    assert.ok(exists("#modal-alert:visible"), "it displays the login error");
    assert.notOk(
      exists(".modal-footer .btn-primary:disabled"),
      "enables the login button"
    );

    // Use the correct password
    await fillIn("#login-account-password", "correct");
    await click(".modal-footer .btn-primary");
    assert.ok(
      exists(".modal-footer .btn-primary:disabled"),
      "disables the login button"
    );
  });

  test("sign in - not activated", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.ok(exists(".login-modal"), "it shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "not-activated");
    await click(".modal-footer .btn-primary");
    assert.strictEqual(
      queryAll(".modal-body b").text(),
      "<small>eviltrout@example.com</small>"
    );
    assert.ok(!exists(".modal-body small"), "it escapes the email address");

    await click(".modal-footer button.resend");
    assert.strictEqual(
      queryAll(".modal-body b").text(),
      "<small>current@example.com</small>"
    );
    assert.ok(!exists(".modal-body small"), "it escapes the email address");
  });

  test("sign in - not activated - edit email", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.ok(exists(".login-modal"), "it shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "not-activated-edit");
    await click(".modal-footer .btn-primary");
    await click(".modal-footer button.edit-email");
    assert.strictEqual(
      queryAll(".activate-new-email").val(),
      "current@example.com"
    );
    assert.strictEqual(
      count(".modal-footer .btn-primary:disabled"),
      1,
      "must change email"
    );
    await fillIn(".activate-new-email", "different@example.com");
    assert.ok(!exists(".modal-footer .btn-primary:disabled"));
    await click(".modal-footer .btn-primary");
    assert.strictEqual(
      queryAll(".modal-body b").text(),
      "different@example.com"
    );
  });

  test("second factor", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.ok(exists(".login-modal"), "it shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "need-second-factor");
    await click(".modal-footer .btn-primary");

    assert.notOk(
      exists("#credentials:visible"),
      "it hides the username and password prompt"
    );
    assert.ok(
      exists("#second-factor:visible"),
      "it displays the second factor prompt"
    );
    assert.notOk(
      exists(".modal-footer .btn-primary:disabled"),
      "enables the login button"
    );

    await fillIn("#login-second-factor", "123456");
    await click(".modal-footer .btn-primary");

    assert.ok(
      exists(".modal-footer .btn-primary:disabled"),
      "disables the login button"
    );
  });

  test("security key", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.ok(exists(".login-modal"), "it shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "need-security-key");
    await click(".modal-footer .btn-primary");

    assert.notOk(
      exists("#credentials:visible"),
      "it hides the username and password prompt"
    );
    assert.notOk(
      exists("#login-second-factor:visible"),
      "it does not display the second factor prompt"
    );
    assert.ok(
      exists("#security-key:visible"),
      "it shows the security key prompt"
    );
    assert.notOk(exists("#login-button:visible"), "hides the login button");
  });

  test("create account", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    assert.ok(exists(".create-account"), "it shows the create account modal");

    await fillIn("#new-account-name", "Dr. Good Tuna");
    await fillIn("#new-account-password", "cool password bro");

    // without this double fill, field will sometimes being empty
    // got consistent repro by having browser search bar focused when starting test
    await fillIn("#new-account-email", "good.tuna@test.com");
    await fillIn("#new-account-email", "good.tuna@test.com");

    // Check username
    await fillIn("#new-account-username", "taken");
    assert.ok(
      exists("#username-validation.bad"),
      "the username validation is bad"
    );
    await click(".modal-footer .btn-primary");

    await fillIn("#new-account-username", "goodtuna");
    assert.ok(
      exists("#username-validation.good"),
      "the username validation is good"
    );

    await click(".modal-footer .btn-primary");
    assert.ok(
      exists(".modal-footer .btn-primary:disabled"),
      "create account is disabled"
    );
  });

  test("second factor backup - valid token", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "need-second-factor");
    await click(".modal-footer .btn-primary");
    await click(".login-modal .toggle-second-factor-method");
    await fillIn("#login-second-factor", "123456");
    await click(".modal-footer .btn-primary");

    assert.ok(
      exists(".modal-footer .btn-primary:disabled"),
      "it closes the modal when the code is valid"
    );
  });

  test("second factor backup - invalid token", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "need-second-factor");
    await click(".modal-footer .btn-primary");
    await click(".login-modal .toggle-second-factor-method");
    await fillIn("#login-second-factor", "something");
    await click(".modal-footer .btn-primary");

    assert.ok(
      exists("#modal-alert:visible"),
      "it shows an error when the code is invalid"
    );
  });
});
