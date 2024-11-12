import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

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

  test("with hide_email_address_taken enabled", async function (assert) {
    await visit("/");
    await click("header .login-button");
    await fillIn("#login-account-name", "someuser@example.com");
    await click("#email-login-link");

    assert.dom(".alert-success").hasHtml(
      I18n.t("email_login.complete_email_found", {
        email: "someuser@example.com",
      }),
      "displays the success message for any email address"
    );
  });
});
