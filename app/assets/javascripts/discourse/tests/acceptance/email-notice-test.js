import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

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
      .exists("alert is displayed when email disabled");
    assert
      .dom(".alert-emails-disabled .text")
      .hasText(I18n.t("emails_are_disabled"), "alert uses the correct text");
  });

  test("when non-staff", async function (assert) {
    this.siteSettings.disable_emails = "non-staff";
    await visit("/");
    assert
      .dom(".alert-emails-disabled")
      .exists("alert is displayed when email disabled for non-staff");
    assert
      .dom(".alert-emails-disabled .text")
      .hasText(
        I18n.t("emails_are_disabled_non_staff"),
        "alert uses the correct text"
      );

    updateCurrentUser({ moderator: true });
    await visit("/");
    assert
      .dom(".alert-emails-disabled")
      .exists("alert is displayed to staff when email disabled for non-staff");
    assert
      .dom(".alert-emails-disabled .text")
      .hasText(
        I18n.t("emails_are_disabled_non_staff"),
        "alert uses the correct text"
      );
  });
});
