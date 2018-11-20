import { acceptance } from "helpers/qunit-helpers";

acceptance("Login Required", {
  settings: {
    login_required: true
  }
});

QUnit.test("redirect", async assert => {
  await visit("/latest");
  assert.equal(currentPath(), "login", "it redirects them to login");

  await click("#site-logo");
  assert.equal(currentPath(), "login", "clicking the logo keeps them on login");

  await click("header .login-button");
  assert.ok(exists(".login-modal"), "they can still access the login modal");

  await click(".modal-header .close");
  assert.ok(invisible(".login-modal"), "it closes the login modal");
});
