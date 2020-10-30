import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, invisible } from "discourse/tests/helpers/qunit-helpers";

acceptance("Login Required", function (needs) {
  needs.settings({ login_required: true });

  test("redirect", async (assert) => {
    await visit("/latest");
    assert.equal(currentPath(), "login", "it redirects them to login");

    await click("#site-logo");
    assert.equal(
      currentPath(),
      "login",
      "clicking the logo keeps them on login"
    );

    await click("header .login-button");
    assert.ok(exists(".login-modal"), "they can still access the login modal");

    await click(".modal-header .close");
    assert.ok(invisible(".login-modal"), "it closes the login modal");
  });
});
