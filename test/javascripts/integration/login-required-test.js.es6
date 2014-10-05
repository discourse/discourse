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

  click('.modal-header .close');
  andThen(function() {
    ok(!exists('.login-modal'), "it closes the login modal");
  });

  click('#search-button');
  andThen(function() {
    ok(exists('.login-modal'), "clicking search opens the login modal");
  });

  click('.modal-header .close');
  andThen(function() {
    ok(!exists('.login-modal'), "it closes the login modal");
  });

  click('#site-map');
  andThen(function() {
    ok(exists('.login-modal'), "site map opens the login modal");
  });
});
