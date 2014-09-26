import { integration } from "helpers/qunit-helpers";

integration("Create Account - User Fields", {
  site: {
    user_fields: [{"id":34,"name":"I've read the terms of service","field_type":"confirm"},
                  {"id":35,"name":"What is your pet's name?","field_type":"text"}]
  }
});

test("create account with user fields", function() {
  visit("/");
  click("header .sign-up-button");

  andThen(function() {
    ok(exists('.create-account'), "it shows the create account modal");
    ok(exists('.user-field'), "it has at least one user field");
    ok(exists('.modal-footer .btn-primary:disabled'), 'create account is disabled at first');
  });

  fillIn('#new-account-name', 'Dr. Good Tuna');
  fillIn('#new-account-password', 'cool password bro');
  fillIn('#new-account-email', 'good.tuna@test.com');
  fillIn('#new-account-username', 'goodtuna');

  andThen(function() {
    ok(exists('#username-validation.good'), 'the username validation is good');
    ok(exists('.modal-footer .btn-primary:disabled'), 'create account is still disabled due to lack of user fields');
  });

  fillIn(".user-field input[type=text]", "Barky");

  andThen(function() {
    ok(exists('.modal-footer .btn-primary:disabled'), 'create account is disabled because field is not checked');
  });

  click(".user-field input[type=checkbox]");
  andThen(function() {
    not(exists('.modal-footer .btn-primary:disabled'), 'create account is disabled because field is not checked');
  });

  click(".user-field input[type=checkbox]");
  andThen(function() {
    ok(exists('.modal-footer .btn-primary:disabled'), 'unclicking the checkbox disables the submit');
  });

});
