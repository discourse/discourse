import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("Create Account - User Fields", function (needs) {
  needs.site({
    user_fields: [
      {
        id: 34,
        name: "I've read the terms of service",
        field_type: "confirm",
        required: true,
      },
      {
        id: 35,
        name: "What is your pet's name?",
        field_type: "text",
        required: true,
      },
      {
        id: 36,
        name: "What's your dad like?",
        field_type: "text",
        required: false,
      },
    ],
  });

  test("create account with user fields", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    assert.dom(".create-account").exists("it shows the create account modal");
    assert.dom(".user-field").exists("it has at least one user field");

    await click(".d-modal__footer .btn-primary");
    assert
      .dom("#account-email-validation")
      .hasText(I18n.t("user.email.required"));

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

    await click(".d-modal__footer .btn-primary");
    await fillIn(".user-field input[type=text]:nth-of-type(1)", "Barky");
    await click(".user-field input[type=checkbox]");
    await click(".d-modal__footer .btn-primary");
  });

  test("can submit with enter", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");
    await triggerKeyEvent("#new-account-email", "keydown", "Enter");

    assert
      .dom("#account-email-validation")
      .hasText(I18n.t("user.email.required"), "hitting Enter triggers action");
  });

  test("shows validation error for user fields", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    await fillIn("#new-account-password", "cool password bro");
    await fillIn(".user-field-whats-your-dad-like input", "cool password bro");

    await click(".d-modal__footer .btn-primary");

    assert
      .dom(".user-field-what-is-your-pets-name .tip.bad")
      .exists("shows required field error");

    assert
      .dom(".user-field-whats-your-dad-like .tip.bad")
      .exists("shows same as password error");
  });
});
