import { click, currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Login Required", function (needs) {
  needs.settings({ login_required: true });

  test("redirect", async function (assert) {
    await visit("/latest");
    assert.strictEqual(
      currentRouteName(),
      "login",
      "it redirects them to login"
    );

    await click("#site-logo");
    assert.strictEqual(
      currentRouteName(),
      "login",
      "clicking the logo keeps them on login"
    );

    await click("header .login-button");
    assert.dom(".login-modal").exists("they can still access the login modal");

    await click(".d-modal__header .modal-close");
    assert.dom(".login-modal").doesNotExist("closes the login modal");
  });
});
