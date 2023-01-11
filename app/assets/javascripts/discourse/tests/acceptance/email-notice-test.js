import {
  acceptance,
  exists,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import I18n from "I18n";

acceptance("Email Disabled Banner", function (needs) {
  needs.user();

  test("when disabled", async function (assert) {
    this.siteSettings.disable_emails = "no";
    await visit("/");
    assert.notOk(
      exists(".alert-emails-disabled"),
      "alert is not displayed when email enabled"
    );
  });

  test("when enabled", async function (assert) {
    this.siteSettings.disable_emails = "yes";
    await visit("/latest");
    assert.ok(
      exists(".alert-emails-disabled"),
      "alert is displayed when email disabled"
    );
    assert.strictEqual(
      query(".alert-emails-disabled").innerText,
      I18n.t("emails_are_disabled"),
      "alert uses the correct text"
    );
  });

  test("when non-staff", async function (assert) {
    this.siteSettings.disable_emails = "non-staff";
    await visit("/");
    assert.ok(
      exists(".alert-emails-disabled"),
      "alert is displayed when email disabled for non-staff"
    );
    assert.strictEqual(
      query(".alert-emails-disabled").innerText,
      I18n.t("emails_are_disabled_non_staff"),
      "alert uses the correct text"
    );

    updateCurrentUser({ moderator: true });
    await visit("/");
    assert.ok(
      exists(".alert-emails-disabled"),
      "alert is displayed to staff when email disabled for non-staff"
    );
    assert.strictEqual(
      query(".alert-emails-disabled").innerText,
      I18n.t("emails_are_disabled_non_staff"),
      "alert uses the correct text"
    );
  });
});
