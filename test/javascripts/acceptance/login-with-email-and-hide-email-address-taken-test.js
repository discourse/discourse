import I18n from "I18n";
import { acceptance } from "helpers/qunit-helpers";
import pretender from "helpers/create-pretender";

acceptance("Login with email - hide email address taken", {
  settings: {
    enable_local_logins_via_email: true,
    hide_email_address_taken: true
  },
  beforeEach() {
    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    pretender.post("/u/email-login", () => {
      return response({ success: "OK" });
    });
  }
});

QUnit.test("with hide_email_address_taken enabled", async assert => {
  await visit("/");
  await click("header .login-button");
  await fillIn("#login-account-name", "someuser@example.com");
  await click(".login-with-email-button");

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
