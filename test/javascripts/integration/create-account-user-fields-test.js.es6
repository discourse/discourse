import { acceptance } from "helpers/qunit-helpers";

acceptance("Create Account - User Fields", {
  site: {
    user_fields: [{"id":34,"name":"I've read the terms of service","field_type":"confirm","required":true},
                  {"id":35,"name":"What is your pet's name?","field_type":"text","required":true},
                  {"id":36,"name":"What's your dad like?","field_type":"text","required":false}]
  }
});

test("create account with user fields", () => {
  visit("/");
  click("header .sign-up-button");

  andThen(() => {
    ok(exists('.create-account'), "it shows the create account modal");
    ok(exists('.user-field'), "it has at least one user field");
    ok(exists('.modal-footer .btn-primary:disabled'), 'create account is disabled at first');
  });

  fillIn('#new-account-name', 'Dr. Good Tuna');
  fillIn('#new-account-password', 'cool password bro');
  fillIn('#new-account-email', 'good.tuna@test.com');
  fillIn('#new-account-username', 'goodtuna');

  andThen(() => {
    ok(exists('#username-validation.good'), 'the username validation is good');
    ok(exists('.modal-footer .btn-primary:disabled'), 'create account is still disabled due to lack of user fields');
  });

  fillIn(".user-field input[type=text]:first", "Barky");

  andThen(() => {
    ok(exists('.modal-footer .btn-primary:disabled'), 'create account is disabled because field is not checked');
  });

  click(".user-field input[type=checkbox]");
  andThen(() => {
    not(exists('.modal-footer .btn-primary:disabled'), 'create account is enabled because field is not checked');
  });

  click(".user-field input[type=checkbox]");
  andThen(() => {
    ok(exists('.modal-footer .btn-primary:disabled'), 'unclicking the checkbox disables the submit');
  });

});
