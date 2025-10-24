import EmberObject from "@ember/object";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const CUSTOM_VALIDATION_REASON = "bad choice";

acceptance("Create Account - User Fields", function (needs) {
  needs.hooks.beforeEach(function () {
    withPluginApi((api) => {
      api.addCustomUserFieldValidationCallback((userField) => {
        if (userField.field.id === 37 && userField.value !== "red") {
          return EmberObject.create({
            failed: true,
            reason: CUSTOM_VALIDATION_REASON,
            element: userField.field.element,
          });
        }
      });
    });
  });

  needs.site({
    user_fields: [
      {
        id: 34,
        name: "I've read the terms of service",
        field_type: "confirm",
        required: true,
        show_on_signup: true,
      },
      {
        id: 35,
        name: "What is your pet's name?",
        field_type: "text",
        required: true,
        show_on_signup: true,
      },
      {
        id: 36,
        name: "What's your dad like?",
        field_type: "text",
        required: false,
        show_on_signup: true,
      },
      {
        id: 37,
        name: "What is your favorite color?",
        field_type: "text",
        required: true,
        show_on_signup: true,
      },
    ],
  });

  test("create account with user fields", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    assert.dom(".signup-fullpage").exists("it shows the signup page");
    assert.dom(".user-field").exists("it has at least one user field");

    await click(".signup-fullpage .btn-primary");
    assert
      .dom("#account-email-validation")
      .hasText(i18n("user.email.required"));

    await fillIn("#new-account-name", "Dr. Good Tuna");
    await fillIn("#new-account-password", "cool password bro");
    await fillIn("#new-account-email", "good.tuna@test.com");
    await fillIn("#new-account-username", "goodtuna");

    assert
      .dom("#username-validation.good")
      .exists("the username validation is good");
    assert
      .dom("#account-email-validation.good")
      .exists("the email validation is good");

    await click(".signup-fullpage .btn-primary");
    await fillIn(".user-field input[type=text]:nth-of-type(1)", "Barky");
    await click(".user-field input[type=checkbox]");
    await click(".signup-fullpage .btn-primary");
  });

  test("shows validation error for user fields", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    await fillIn("#new-account-password", "cool password bro");
    await fillIn(".user-field-whats-your-dad-like input", "cool password bro");

    await click(".signup-fullpage .btn-primary");

    assert
      .dom(".user-field-what-is-your-pets-name .tip.bad")
      .exists("shows required field error");

    assert
      .dom(".user-field-ive-read-the-terms-of-service .tip.bad")
      .exists("shows required field error");

    assert
      .dom(".user-field-whats-your-dad-like .tip.bad")
      .exists("shows same as password error");
  });

  test("allows for custom validations of user fields", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    await fillIn(".user-field-what-is-your-favorite-color input", "blue");

    assert
      .dom(".user-field-what-is-your-favorite-color .tip.bad")
      .doesNotExist(
        "it does not show error message until the form is submitted"
      );

    await click(".signup-fullpage .btn-primary");

    assert
      .dom(".user-field-what-is-your-favorite-color .tip.bad")
      .hasText(CUSTOM_VALIDATION_REASON, "shows custom error message");
  });

  test("it does not submit the form when custom validation fails", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    // incorrect value for custom validation
    await fillIn(".user-field-what-is-your-favorite-color input", "blue");

    await fillIn("#new-account-name", "Dr. Good Tuna");
    await fillIn("#new-account-password", "cool password bro");
    await fillIn("#new-account-email", "good.tuna@test.com");
    await fillIn("#new-account-username", "goodtuna");
    await fillIn(".user-field input[type=text]:nth-of-type(1)", "Barky");
    await click(".user-field input[type=checkbox]");

    await click(".signup-fullpage .btn-primary");
    assert
      .dom(".user-field-what-is-your-favorite-color .tip.bad")
      .hasText(
        CUSTOM_VALIDATION_REASON,
        "shows custom error message, and the form is not submitted"
      );
  });
});
