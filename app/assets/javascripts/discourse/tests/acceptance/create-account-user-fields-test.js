import {
  acceptance,
  count,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";

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

    assert.ok(exists(".create-account"), "it shows the create account modal");
    assert.ok(exists(".user-field"), "it has at least one user field");

    await click(".modal-footer .btn-primary");
    assert.strictEqual(
      query("#account-email-validation").innerText.trim(),
      "Please enter an email address"
    );

    await fillIn("#new-account-name", "Dr. Good Tuna");
    await fillIn("#new-account-password", "cool password bro");
    await fillIn("#new-account-email", "good.tuna@test.com");
    await fillIn("#new-account-username", "goodtuna");

    assert.ok(
      exists("#username-validation.good"),
      "the username validation is good"
    );
    assert.ok(
      exists("#account-email-validation.good"),
      "the email validation is good"
    );

    await click(".modal-footer .btn-primary");
    await fillIn(".user-field input[type=text]:nth-of-type(1)", "Barky");
    await click(".user-field input[type=checkbox]");
    await click(".modal-footer .btn-primary");
  });

  test("can submit with enter", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");
    await triggerKeyEvent(".modal-footer .btn-primary", "keydown", "Enter");

    assert.strictEqual(
      count("#modal-alert:visible"),
      1,
      "hitting Enter triggers action"
    );
  });

  test("shows validation error for user fields", async function (assert) {
    await visit("/");
    await click("header .sign-up-button");

    await fillIn("#new-account-password", "cool password bro");
    await fillIn(".user-field-whats-your-dad-like input", "cool password bro");

    await click(".modal-footer .btn-primary");

    assert.ok(
      exists(".user-field-what-is-your-pets-name .tip.bad"),
      "shows required field error"
    );

    assert.ok(
      exists(".user-field-whats-your-dad-like .tip.bad"),
      "shows same as password error"
    );
  });
});
