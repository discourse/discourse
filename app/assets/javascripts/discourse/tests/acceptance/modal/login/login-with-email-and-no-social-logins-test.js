import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Login with email - no social logins", function (needs) {
  needs.settings({ enable_local_logins_via_email: true });
  needs.pretender((server, helper) => {
    server.post("/u/email-login", () => helper.response({ success: "OK" }));
  });

  test("with login with email enabled", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.dom("#email-login-link").exists();
  });

  test("with login with email disabled", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.dom(".login-buttons").doesNotExist();
  });
});
