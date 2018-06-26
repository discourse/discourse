import { acceptance } from "helpers/qunit-helpers";

acceptance("Signing In - Mobile", { mobileView: true });

QUnit.test("sign in", assert => {
  visit("/");
  click("header .login-button");
  andThen(() => {
    assert.ok(exists("#login-form"), "it shows the login modal");
  });
});
