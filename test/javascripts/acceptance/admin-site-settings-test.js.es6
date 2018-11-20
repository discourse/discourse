import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - Site Settings", {
  loggedIn: true,

  pretend(server, helper) {
    server.put("/admin/site_settings/**", () =>
      helper.response({ success: "OK" })
    );
  }
});

QUnit.test("changing value updates dirty state", async assert => {
  await visit("/admin/site_settings");
  await fillIn("#setting-filter", "title");
  assert.equal(count(".row.setting"), 1, "filter returns 1 site setting");
  assert.ok(!exists(".row.setting.overridden"), "setting isn't overriden");

  await fillIn(".input-setting-string", "Test");
  await click("button.cancel");
  assert.ok(
    !exists(".row.setting.overridden"),
    "canceling doesn't mark setting as overriden"
  );

  await fillIn(".input-setting-string", "Test");
  await click("button.ok");
  assert.ok(
    exists(".row.setting.overridden"),
    "saving marks setting as overriden"
  );

  await click("button.undo");
  assert.ok(
    !exists(".row.setting.overridden"),
    "setting isn't marked as overriden after undo"
  );

  await fillIn(".input-setting-string", "Test");
  await keyEvent(".input-setting-string", "keydown", 13); // enter
  assert.ok(
    exists(".row.setting.overridden"),
    "saving via Enter key marks setting as overriden"
  );
});
