import { acceptance } from "helpers/qunit-helpers";

acceptance("Login with email - no social logins", {
  settings: {
    enable_local_logins_via_email: true
  },
  pretend(server, helper) {
    server.post("/u/email-login", () => helper.response({ success: "OK" }));
  }
});

QUnit.test("with login with email enabled", async assert => {
  await visit("/");
  await click("header .login-button");

  assert.ok(exists(".login-with-email-button"));
});

QUnit.test("with login with email disabled", async assert => {
  await visit("/");
  await click("header .login-button");

  assert.notOk(find(".login-buttons").is(":visible"));
});
