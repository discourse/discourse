import { acceptance } from "helpers/qunit-helpers";

acceptance("Login with email - hide email address taken", {
  settings: {
    enable_local_logins_via_email: true,
    hide_email_address_taken: true
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

QUnit.test("with hide_email_address_taken enabled", assert => {
  visit("/");
  click("header .login-button");
  fillIn("#login-account-name", "someuser@example.com");
  click(".login-with-email-button");

  andThen(() => {
    assert.equal(
      find(".alert-success")
        .html()
        .trim(),
      I18n.t("email_login.complete_email_found", {
        email: "someuser@example.com"
      }),
      "it should display the success message for any email address"
    );
  });
});
