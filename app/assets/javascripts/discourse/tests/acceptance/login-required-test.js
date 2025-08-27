import { click, currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Login Required - Full page login", function (needs) {
  needs.settings({ login_required: true });

  test("page", async function (assert) {
    await visit("/");
    assert.strictEqual(
      currentRouteName(),
      "discovery.login-required",
      "it shows the login required splash"
    );

    await click(".login-button");
    assert.dom(".login-left-side").exists("login form is shown");
    assert
      .dom(".login-welcome")
      .doesNotExist("login welcome is no longer shown");

    await click(".logo-big");
    assert.dom(".login-left-side").doesNotExist("closes the login modal");
    assert.dom(".login-welcome").exists("login welcome is shown");
  });
});
