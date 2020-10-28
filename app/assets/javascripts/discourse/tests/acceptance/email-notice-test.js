import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

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
  });

  test("when non-staff", async function (assert) {
    this.siteSettings.disable_emails = "non-staff";
    await visit("/");
    assert.ok(
      exists(".alert-emails-disabled"),
      "alert is displayed when email disabled for non-staff"
    );

    updateCurrentUser({ moderator: true });
    await visit("/");
    assert.ok(
      exists(".alert-emails-disabled"),
      "alert is displayed to staff when email disabled for non-staff"
    );
  });
});
