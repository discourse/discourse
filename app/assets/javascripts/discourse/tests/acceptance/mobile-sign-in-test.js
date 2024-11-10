import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Signing In - Mobile", function (needs) {
  needs.mobileView();

  test("sign in", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.dom("#login-form").exists("shows the login modal");
  });
});
