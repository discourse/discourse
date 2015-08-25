import { acceptance } from "helpers/qunit-helpers";

acceptance("Login Required", {
  settings: {
    login_required: true
  }
});

test("redirect", () => {
  visit('/latest');
  andThen(() => {
    equal(currentPath(), "login", "it redirects them to login");
  });

  click('#site-logo');
  andThen(() => {
    equal(currentPath(), "login", "clicking the logo keeps them on login");
  });

  click('header .login-button');
  andThen(() => {
    ok(exists('.login-modal'), "they can still access the login modal");
  });

  click('.modal-header .close');
  andThen(() => {
    ok(invisible('.login-modal'), "it closes the login modal");
  });

  click('#search-button');
  andThen(() => {
    ok(exists('.login-modal'), "clicking search opens the login modal");
  });

  click('.modal-header .close');
  andThen(() => {
    ok(invisible('.login-modal'), "it closes the login modal");
  });

  click('#toggle-hamburger-menu');
  andThen(() => {
    ok(exists('.login-modal'), "site map opens the login modal");
  });
});
