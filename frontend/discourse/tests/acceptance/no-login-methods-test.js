import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("No login methods configured", function (needs) {
  needs.settings({
    enable_local_logins: false,
    enable_local_logins_via_code: false,
  });

  test("the login page explains that no login methods are configured", async function (assert) {
    await visit("/login");

    assert.dom(".login-fullpage .no-login-methods-configured").exists();
    assert.dom("#login-form").doesNotExist();
  });

  test("the signup page explains that no login methods are configured", async function (assert) {
    await visit("/signup");

    assert.dom(".signup-fullpage .no-login-methods-configured").exists();
    assert.dom("#login-form").doesNotExist();
    assert.dom(".signup-progress-bar").doesNotExist();
  });
});
