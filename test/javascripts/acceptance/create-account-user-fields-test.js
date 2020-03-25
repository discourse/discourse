import { acceptance } from "helpers/qunit-helpers";

acceptance("Create Account - User Fields", {
  site: {
    user_fields: [
      {
        id: 34,
        name: "I've read the terms of service",
        field_type: "confirm",
        required: true
      },
      {
        id: 35,
        name: "What is your pet's name?",
        field_type: "text",
        required: true
      },
      {
        id: 36,
        name: "What's your dad like?",
        field_type: "text",
        required: false
      }
    ]
  }
});

QUnit.test("create account with user fields", async assert => {
  await visit("/");
  await click("header .sign-up-button");

  assert.ok(exists(".create-account"), "it shows the create account modal");
  assert.ok(exists(".user-field"), "it has at least one user field");
  assert.ok(
    exists(".modal-footer .btn-primary:disabled"),
    "create account is disabled at first"
  );

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
  assert.ok(
    exists(".modal-footer .btn-primary:disabled"),
    "create account is still disabled due to lack of user fields"
  );

  await fillIn(".user-field input[type=text]:first", "Barky");

  assert.ok(
    exists(".modal-footer .btn-primary:disabled"),
    "create account is disabled because field is not checked"
  );

  await click(".user-field input[type=checkbox]");

  assert.ok(
    !exists(".modal-footer .btn-primary:disabled"),
    "create account is enabled because field is checked"
  );

  await click(".user-field input[type=checkbox]");
  assert.ok(
    exists(".modal-footer .btn-primary:disabled"),
    "unchecking the checkbox disables the create account button"
  );
});
