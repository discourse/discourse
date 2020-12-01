import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Signing In - Mobile", function (needs) {
  needs.mobileView();
  test("sign in", async function (assert) {
    await visit("/");
    await click("header .login-button");
    assert.ok(exists("#login-form"), "it shows the login modal");
  });
});
