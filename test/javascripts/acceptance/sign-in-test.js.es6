import { acceptance } from "helpers/qunit-helpers";
acceptance("Signing In");

test("sign in", () => {
  visit("/");
  click("header .login-button");
  andThen(() => {
    ok(exists('.login-modal'), "it shows the login modal");
  });

  // Test invalid password first
  fillIn('#login-account-name', 'eviltrout');
  fillIn('#login-account-password', 'incorrect');
  click('.modal-footer .btn-primary');
  andThen(() => {
    ok(exists('#modal-alert:visible'), 'it displays the login error');
    not(exists('.modal-footer .btn-primary:disabled'), "enables the login button");
  });

  // Use the correct password
  fillIn('#login-account-password', 'correct');
  click('.modal-footer .btn-primary');
  andThen(() => {
    ok(exists('.modal-footer .btn-primary:disabled'), "disables the login button");
  });
});

test("sign in - not activated", () => {
  visit("/");
  andThen(() => {
    click("header .login-button");
    andThen(() => {
      ok(exists('.login-modal'), "it shows the login modal");
    });

    fillIn('#login-account-name', 'eviltrout');
    fillIn('#login-account-password', 'not-activated');
    click('.modal-footer .btn-primary');
    andThen(() => {
      equal(find('.modal-body b').text(), '<small>eviltrout@example.com</small>');
      ok(!exists('.modal-body small'), 'it escapes the email address');
    });

    click('.modal-body .resend-link');
    andThen(() => {
      equal(find('.modal-body b').text(), '<small>current@example.com</small>');
      ok(!exists('.modal-body small'), 'it escapes the email address');
    });


  });
});


test("create account", () => {
  visit("/");
  click("header .sign-up-button");

  andThen(() => {
    ok(exists('.create-account'), "it shows the create account modal");
    ok(exists('.modal-footer .btn-primary:disabled'), 'create account is disabled at first');
  });

  fillIn('#new-account-name', 'Dr. Good Tuna');
  fillIn('#new-account-password', 'cool password bro');

  // Check username
  fillIn('#new-account-email', 'good.tuna@test.com');
  fillIn('#new-account-username', 'taken');
  andThen(() => {
    ok(exists('#username-validation.bad'), 'the username validation is bad');
    ok(exists('.modal-footer .btn-primary:disabled'), 'create account is still disabled');
  });

  fillIn('#new-account-username', 'goodtuna');
  andThen(() => {
    ok(exists('#username-validation.good'), 'the username validation is good');
    not(exists('.modal-footer .btn-primary:disabled'), 'create account is enabled');
  });

  click('.modal-footer .btn-primary');
  andThen(() => {
    ok(exists('.modal-footer .btn-primary:disabled'), "create account is disabled");
  });
});
