import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Login with email - no social logins", function (needs) {
  needs.settings({ enable_local_logins_via_email: true });
  needs.pretender((server, helper) => {
    server.post("/u/email-login", () => helper.response({ success: "OK" }));
  });
  test("with login with email enabled", async (assert) => {
    await visit("/");
    await click("header .login-button");

    assert.ok(exists(".login-with-email-button"));
  });

  test("with login with email disabled", async (assert) => {
    await visit("/");
    await click("header .login-button");

    assert.notOk(find(".login-buttons").is(":visible"));
  });
});
