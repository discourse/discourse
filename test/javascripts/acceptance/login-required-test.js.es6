import { acceptance } from "helpers/qunit-helpers";

acceptance("Login Required", {
  settings: {
    login_required: true
  }
});

QUnit.test("redirect", assert => {
  visit("/latest");
  andThen(() => {
    assert.equal(currentPath(), "login", "it redirects them to login");
  });

  click("#site-logo");
  andThen(() => {
    assert.equal(
      currentPath(),
      "login",
      "clicking the logo keeps them on login"
    );
  });

  click("header .login-button");
  andThen(() => {
    assert.ok(exists(".login-modal"), "they can still access the login modal");
  });

  click(".modal-header .close");
  andThen(() => {
    assert.ok(invisible(".login-modal"), "it closes the login modal");
  });
});
