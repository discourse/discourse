import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Login with email - no social logins", function (needs) {
  needs.settings({ enable_local_logins_via_email: true });
  needs.pretender((server, helper) => {
    server.post("/u/email-login", () => helper.response({ success: "OK" }));
  });
  test("with login with email enabled", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.ok(exists("#email-login-link"));
  });

  test("with login with email disabled", async function (assert) {
    await visit("/");
    await click("header .login-button");

    assert.notOk(queryAll(".login-buttons").is(":visible"));
  });
});
