import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Login with email - hide email address taken", function (needs) {
  needs.settings({
    enable_local_logins_via_email: true,
    hide_email_address_taken: true,
  });

  needs.pretender((server, helper) => {
    server.post("/u/email-login", () => {
      return helper.response({ success: "OK" });
    });
  });

  test("with hide_email_address_taken enabled", async (assert) => {
    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "someuser@example.com");
    await click(".login-with-email-button");

    assert.equal(
      find(".alert-success").html().trim(),
      I18n.t("email_login.complete_email_found", {
        email: "someuser@example.com",
      }),
      "it should display the success message for any email address"
    );
  });
});
