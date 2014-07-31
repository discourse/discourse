integration("Signing In");

test("sign in with incorrect credentials", function() {
  visit("/");
  click("header .login-button");
  andThen(function() {
    ok(exists('.login-modal'), "it shows the login modal");
  });
  fillIn('#login-account-name', 'eviltrout');
  fillIn('#login-account-password', 'where da plankton at?');

  // The fixture is set to invalid login
  click('.modal-footer .btn-primary');
  andThen(function() {
    // ok(exists('#modal-alert:visible', 'it displays the login error'));
  });
});
