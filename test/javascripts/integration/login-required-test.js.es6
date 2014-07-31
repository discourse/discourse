integration("Login Required", {
  settings: {
    login_required: true
  }
});

test("redirect", function() {
  visit('/latest');
  andThen(function() {
    equal(currentPath(), "login", "it redirects them to login");
  });

  click('#site-logo');
  andThen(function() {
    equal(currentPath(), "login", "clicking the logo keeps them on login");
  });

  click('header .login-button');
  andThen(function() {
    ok(exists('.login-modal'), "they can still access the login modal");
  });
});
