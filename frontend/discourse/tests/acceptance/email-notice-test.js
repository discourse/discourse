import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Email Disabled Banner", function (needs) {
  needs.user();

  test("when disabled", async function (assert) {
    this.siteSettings.disable_emails = "no";
    await visit("/");
    assert
      .dom(".alert-emails-disabled")
      .doesNotExist("alert is not displayed when email enabled");
  });

  test("when enabled", async function (assert) {
    this.siteSettings.disable_emails = "yes";

    await visit("/latest");
    assert
      .dom(".alert-emails-disabled")
      .doesNotExist("alert is not displayed on non-admin routes");

    updateCurrentUser({ admin: true });
    await visit("/admin");
    assert
      .dom(".alert-emails-disabled")
      .exists("alert is displayed on admin routes when email disabled");
    assert
      .dom(".alert-emails-disabled .text")
      .hasText(i18n("emails_are_disabled"), "alert uses the correct text");
  });

  test("when non-staff", async function (assert) {
    this.siteSettings.disable_emails = "non-staff";

    await visit("/latest");
    assert
      .dom(".alert-emails-disabled")
      .doesNotExist("alert is not displayed on non-admin routes");

    updateCurrentUser({ admin: true });
    await visit("/admin");
    assert
      .dom(".alert-emails-disabled")
      .exists(
        "alert is displayed on admin routes when email disabled for non-staff"
      );
    assert
      .dom(".alert-emails-disabled .text")
      .hasText(
        i18n("emails_are_disabled_non_staff"),
        "alert uses the correct text"
      );
  });
});
