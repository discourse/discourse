import { acceptance } from "helpers/qunit-helpers";

acceptance("Email Disabled Banner", {
  loggedIn: true
});

QUnit.test("shows banner when required", async assert => {
  Discourse.SiteSettings.disable_email = "no";
  await visit("/");
  assert.notOk(
    exists(".alert-emails-disabled"),
    "alert is not displayed when email enabled"
  );

  Discourse.SiteSettings.disable_email = "yes";
  await visit("/");
  assert.notOk(
    exists(".alert-emails-disabled"),
    "alert is displayed when email disabled"
  );

  Discourse.SiteSettings.disable_email = "non-staff";
  await visit("/");
  assert.notOk(
    exists(".alert-emails-disabled"),
    "alert is displayed when email disabled for non-staff"
  );
});
