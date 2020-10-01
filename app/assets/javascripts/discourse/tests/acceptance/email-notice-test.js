import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Email Disabled Banner", {
  loggedIn: true,
});

QUnit.test("when disabled", async function (assert) {
  this.siteSettings.disable_emails = "no";
  await visit("/");
  assert.notOk(
    exists(".alert-emails-disabled"),
    "alert is not displayed when email enabled"
  );
});

QUnit.test("when enabled", async function (assert) {
  this.siteSettings.disable_emails = "yes";
  await visit("/latest");
  assert.ok(
    exists(".alert-emails-disabled"),
    "alert is displayed when email disabled"
  );
});

QUnit.test("when non-staff", async function (assert) {
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
