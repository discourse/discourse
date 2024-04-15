import { click, currentRouteName, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  exists,
  invisible,
} from "discourse/tests/helpers/qunit-helpers";

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
    assert.ok(exists(".login-modal"), "they can still access the login modal");

    await click(".d-modal__header .modal-close");
    assert.ok(invisible(".login-modal"), "it closes the login modal");
  });
});
