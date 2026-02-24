import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Email Disabled Banner - disable_emails setting", function (needs) {
  needs.user();
  needs.site({ email_configured: true });

  test("no banner when emails are enabled", async function (assert) {
    this.siteSettings.disable_emails = "no";
    await visit("/");
    assert.dom(".alert-emails-disabled").doesNotExist();
  });

  test("shows globally when disable_emails is yes", async function (assert) {
    this.siteSettings.disable_emails = "yes";
    await visit("/latest");
    assert.dom(".alert-emails-disabled").exists();
    assert
      .dom(".alert-emails-disabled .text")
      .hasText(i18n("emails_are_disabled"));
  });

  test("shows globally when disable_emails is non-staff", async function (assert) {
    this.siteSettings.disable_emails = "non-staff";
    await visit("/latest");
    assert.dom(".alert-emails-disabled").exists();
    assert
      .dom(".alert-emails-disabled .text")
      .hasText(i18n("emails_are_disabled_non_staff"));
  });
});

acceptance("Email Disabled Banner - no SMTP configured", function (needs) {
  needs.user();
  needs.site({ email_configured: false });

  test("no banner on regular routes", async function (assert) {
    this.siteSettings.disable_emails = "no";
    await visit("/latest");
    assert.dom(".alert-emails-disabled").doesNotExist();
  });

  test("shows on email-related routes when no SMTP", async function (assert) {
    this.siteSettings.disable_emails = "no";
    await visit("/login");
    assert.dom(".alert-emails-disabled").exists();
    assert
      .dom(".alert-emails-disabled .text")
      .hasText(i18n("emails_are_disabled_no_smtp"));
  });

  test("disable_emails setting takes precedence and shows globally", async function (assert) {
    this.siteSettings.disable_emails = "yes";
    await visit("/latest");
    assert.dom(".alert-emails-disabled").exists();
    assert
      .dom(".alert-emails-disabled .text")
      .hasText(i18n("emails_are_disabled"));
  });

  test("shows on admin routes when no SMTP", async function (assert) {
    this.siteSettings.disable_emails = "no";
    updateCurrentUser({ admin: true });
    await visit("/admin");
    assert.dom(".alert-emails-disabled").exists();
  });
});
