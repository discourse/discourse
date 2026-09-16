import {
  click,
  fillIn,
  find,
  settled,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import pretender, {
  parsePostData,
} from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function sessionRequests() {
  return pretender.handledRequests.filter(
    ({ method, url }) => method === "POST" && url.endsWith("/session")
  );
}

acceptance("Signing In", function (needs) {
  needs.settings({ enable_local_logins_via_code: false });

  test("submits username credentials with the login button", async function (assert) {
    await visit("/login");

    assert
      .dom("#login-account-name")
      .hasAttribute("type", "text", "accepts usernames")
      .hasAttribute("inputmode", "email", "uses an email-friendly keyboard");
    assert
      .dom("#login-button")
      .hasAttribute("type", "submit", "is a native submit button")
      .hasAttribute("form", "login-form", "submits the login form");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "incorrect");
    await click("#login-button");

    const requests = sessionRequests();
    assert.strictEqual(requests.length, 1, "sends one login request");
    assert.strictEqual(
      parsePostData(requests[0].requestBody).login,
      "eviltrout",
      "submits the username"
    );
    assert.dom(".code-login-form").doesNotExist("keeps the password flow");
  });

  test("submits email credentials once when pressing Enter", async function (assert) {
    await visit("/login");
    await fillIn("#login-account-name", "eviltrout@example.com");
    await fillIn("#login-account-password", "incorrect");

    await triggerKeyEvent("#login-account-password", "keydown", "Enter");
    // Synthetic key events do not perform the browser's default form submission.
    find("#login-form").requestSubmit();
    await settled();

    const requests = sessionRequests();
    assert.strictEqual(requests.length, 1, "sends one login request");
    assert.strictEqual(
      parsePostData(requests[0].requestBody).login,
      "eviltrout@example.com",
      "submits the email address"
    );
    assert.dom(".code-login-form").doesNotExist("keeps the password flow");
  });

  test("sign in", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.dom(".login-fullpage").exists("shows the login modal");

    // Test invalid password first
    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "incorrect");
    await click(".login-fullpage .btn-primary");
    assert.dom(".alert-error").exists("displays the login error");
    assert
      .dom(".login-fullpage .btn-primary")
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
    await click(".login-fullpage .btn-primary");
    assert
      .dom(".login-fullpage .btn-primary")
      .isDisabled("disables the login button");
  });

  test("sign in - not activated", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.dom(".login-fullpage").exists("shows the login modal");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "not-activated");
    await click(".login-fullpage .btn-primary");
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
    assert.dom(".login-fullpage").exists("shows the login page");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "not-activated-edit");
    await click(".login-fullpage .btn-primary");

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

    assert.dom(".login-fullpage").exists("shows the login page");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "need-second-factor");
    await click(".login-fullpage .btn-primary");

    assert
      .dom("#credentials")
      .isNotVisible("hides the username and password prompt");
    assert.dom("#second-factor").isVisible("displays the second factor prompt");

    assert
      .dom(".login-fullpage .btn-primary")
      .isEnabled("enables the login button");

    await fillIn("#login-second-factor", "123456");

    assert
      .dom(".login-fullpage .btn-primary")
      .isDisabled("disables the login button");
  });

  test("security key", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.dom(".login-fullpage").exists("shows the login page");

    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "need-security-key");
    await click(".login-fullpage .btn-primary");

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
    await fillIn("#login-account-password", "need-second-factor");
    await click(".login-fullpage .btn-primary");
    await click(".login-fullpage .toggle-second-factor-method");
    await fillIn("#login-second-factor", "123456");
    await click(".login-fullpage .btn-primary");

    assert.dom(".login-fullpage .btn-primary").isDisabled();
  });

  test("second factor backup - invalid token", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "eviltrout");
    await fillIn("#login-account-password", "need-second-factor");
    await click(".login-fullpage .btn-primary");
    await click(".login-fullpage .toggle-second-factor-method");
    await fillIn("#login-second-factor", "something");
    await click(".login-fullpage .btn-primary");

    assert
      .dom(".alert-error")
      .exists("shows an error when the code is invalid");
  });
});

acceptance("Signing In with code", function (needs) {
  needs.settings({ enable_local_logins_via_code: true });

  test("defaults to password login and offers code login", async function (assert) {
    await visit("/login");

    assert.dom("#login-form").exists("shows the password form");
    assert.dom(".code-login-form").doesNotExist("does not open code login");
    assert.dom("#one-time-code-link").exists("offers code login");

    await fillIn("#login-account-name", "person@example.com");
    await click("#one-time-code-link");

    assert.dom(".code-login-form").exists("opens code login explicitly");
    assert
      .dom(".code-login-form__email-step input")
      .hasValue("person@example.com", "preserves the entered email");
    assert
      .dom("#login-buttons .btn-social")
      .isVisible("keeps external login methods accessible");

    await fillIn(".code-login-form__email-step input", "updated@example.com");
    await click(".code-login-form__password-toggle");

    assert.dom("#login-form").exists("returns to password login");
    assert
      .dom("#login-account-name")
      .hasValue("updated@example.com", "preserves the updated email");
    assert.strictEqual(sessionRequests().length, 0, "does not submit a login");
  });

  test("only an available explicit code mode opens code login", async function (assert) {
    await visit("/login?mode=code");
    assert.dom(".code-login-form").exists("opens the available code login");

    await visit("/login?mode=unknown");
    assert.dom("#login-form").exists("ignores an unknown login mode");

    this.siteSettings.enable_local_logins_via_code = false;
    await visit("/login?mode=code");
    assert.dom("#login-form").exists("ignores unavailable code login");
    assert
      .dom("#one-time-code-link")
      .doesNotExist("hides the unavailable option");
  });
});
