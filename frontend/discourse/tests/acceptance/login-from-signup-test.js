import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Login Fields - From Signup Form", function () {
  test("autofills login field with signup email value", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");
    await fillIn("#new-account-email", "test@example.com");

    await click(".signup-page-cta__login");

    assert
      .dom("#login-account-name")
      .hasValue("test@example.com", "login name is autofilled with email");
  });

  test("autofills login field with signup username value when email field is empty", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");
    await fillIn("#new-account-username", "testuser");

    await click(".signup-page-cta__login");

    assert
      .dom("#login-account-name")
      .hasValue("testuser", "login name is autofilled with username");
  });

  test("prefers email over username when both email and username fields have been filled", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");
    await fillIn("#new-account-email", "test@example.com");
    await fillIn("#new-account-username", "testuser");

    await click(".signup-page-cta__login");

    assert
      .dom("#login-account-name")
      .hasValue(
        "test@example.com",
        "login name is autofilled with email when both are present"
      );
  });

  test("preserves email on round-trip", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");
    await fillIn("#new-account-email", "test@example.com");

    // Go to login
    await click(".signup-page-cta__login");

    assert
      .dom("#login-account-name")
      .hasValue("test@example.com", "login has email");

    // Go back to signup
    await click("#new-account-link");

    assert
      .dom("#new-account-email")
      .hasValue("test@example.com", "email is preserved on round-trip");
  });

  test("preserves username on round-trip when email field is empty", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");
    await fillIn("#new-account-username", "testuser");

    // Go to login
    await click(".signup-page-cta__login");

    assert
      .dom("#login-account-name")
      .hasValue("testuser", "login has username");

    // Go back to signup
    await click("#new-account-link");

    assert
      .dom("#new-account-username")
      .hasValue("testuser", "username is preserved on round-trip");
  });
});

acceptance("Code login - switching authentication pages", function (needs) {
  needs.settings({
    enable_local_logins_via_code: true,
    enable_local_logins_via_email: true,
  });

  test("can switch from signup to login after entering an email", async function (assert) {
    await visit("/signup");
    await fillIn(".code-login-form__email-step input", "person@example.com");

    await visit("/login");

    assert.strictEqual(currentURL(), "/login");
    assert.dom(".dialog-body").doesNotExist();
    assert.dom(".login-fullpage").exists();
  });

  test("can switch from code login to signup after entering an email", async function (assert) {
    await visit("/login?mode=code");
    await fillIn(".code-login-form__email-step input", "person@example.com");

    await visit("/signup");

    assert.strictEqual(currentURL(), "/signup");
    assert.dom(".dialog-body").doesNotExist();
    assert.dom(".signup-fullpage").exists();
  });

  test("still confirms leaving an unfinished signup for another page", async function (assert) {
    await visit("/signup");
    await fillIn(".code-login-form__email-step input", "person@example.com");

    await assert.rejects(visit("/latest"), /TransitionAborted/);

    assert.strictEqual(currentURL(), "/signup");
    assert.dom(".dialog-body").exists();
    await click(".dialog-footer .btn-primary");
    assert.strictEqual(currentURL(), "/latest");
  });
});
