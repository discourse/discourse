import { acceptance } from "helpers/qunit-helpers";

acceptance("Signing In - Mobile", { mobileView: true });

test("sign in", () => {
  visit("/");
  click("header .login-button");
  andThen(() => {
    ok(exists('#login-form'), "it shows the login modal");
  });
});
