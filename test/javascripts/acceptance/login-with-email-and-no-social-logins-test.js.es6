import { acceptance } from "helpers/qunit-helpers";

acceptance("Login with email - no social logins", {
  settings: {
    enable_local_logins_via_email: true
  },
  beforeEach() {
    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    // prettier-ignore
    server.post("/u/email-login", () => { // eslint-disable-line no-undef
      return response({ success: "OK" });
    });
  }
});

QUnit.test("with login with email enabled", assert => {
  visit("/");
  click("header .login-button");

  andThen(() => {
    assert.ok(exists(".login-with-email-button"));
  });
});

QUnit.test("with login with email disabled", assert => {
  visit("/");
  click("header .login-button");

  andThen(() => {
    assert.notOk(find(".login-buttons").is(":visible"));
  });
});
