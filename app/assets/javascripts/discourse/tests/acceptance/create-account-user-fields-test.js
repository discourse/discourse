import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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

  test("create account with user fields", async (assert) => {
    await visit("/");
    await click("header .sign-up-button");

    assert.ok(exists(".create-account"), "it shows the create account modal");
    assert.ok(exists(".user-field"), "it has at least one user field");

    await click(".modal-footer .btn-primary");
    assert.ok(exists("#modal-alert"), "it shows the required field alert");
    assert.equal(find("#modal-alert").text(), "Please enter an email address");

    await fillIn("#new-account-name", "Dr. Good Tuna");
    await fillIn("#new-account-password", "cool password bro");
    // without this double fill, field will sometimes being empty
    // got consistent repro by having browser search bar focused when starting test
    await fillIn("#new-account-email", "good.tuna@test.com");
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
    assert.equal(find("#modal-alert")[0].style.display, "");

    await fillIn(".user-field input[type=text]:first", "Barky");
    await click(".user-field input[type=checkbox]");

    await click(".modal-footer .btn-primary");
    assert.equal(find("#modal-alert")[0].style.display, "none");
  });
});
