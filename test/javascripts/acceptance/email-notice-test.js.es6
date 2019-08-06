import { acceptance, updateCurrentUser } from "helpers/qunit-helpers";

acceptance("Email Disabled Banner", {
  loggedIn: true
});

QUnit.test("shows banner when required", async assert => {
  Discourse.set("SiteSettings.disable_emails", "no");
  await visit("/");
  assert.notOk(
    exists(".alert-emails-disabled"),
    "alert is not displayed when email enabled"
  );

  Discourse.set("SiteSettings.disable_emails", "yes");
  await visit("/latest");
  assert.ok(
    exists(".alert-emails-disabled"),
    "alert is displayed when email disabled"
  );

  Discourse.set("SiteSettings.disable_emails", "non-staff");
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
