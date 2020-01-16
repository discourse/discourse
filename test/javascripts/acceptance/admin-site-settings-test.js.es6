import { acceptance } from "helpers/qunit-helpers";
import siteSettingFixture from "fixtures/site_settings";

var titleOverride = undefined;

acceptance("Admin - Site Settings", {
  loggedIn: true,
  beforeEach() {
    titleOverride = undefined;
  },

  pretend(server, helper) {
    server.put("/admin/site_settings/title", body => {
      titleOverride = body.requestBody.split("=")[1];
      return helper.response({ success: "OK" });
    });
    server.get("/admin/site_settings", () => {
      const fixtures = siteSettingFixture["/admin/site_settings"].site_settings;
      const titleSetting = Object.assign({}, fixtures[0]);

      if (titleOverride) {
        titleSetting.value = titleOverride;
      }
      const response = {
        site_settings: [titleSetting, ...fixtures.slice(1)]
      };
      return helper.response(response);
    });
  }
});

QUnit.test("upload site setting", async assert => {
  await visit("/admin/site_settings");

  assert.ok(
    exists(".row.setting.upload .image-uploader"),
    "image uploader is present"
  );

  assert.ok(exists(".row.setting.upload .undo"), "undo button is present");
});

QUnit.test("changing value updates dirty state", async assert => {
  await visit("/admin/site_settings");
  await fillIn("#setting-filter", " title ");
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

  await click("button.cancel");
  assert.ok(
    exists(".row.setting.overridden"),
    "setting is marked as overriden after cancel"
  );

  await click("button.undo");
  await click("button.ok");
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

QUnit.test(
  "always shows filtered site settings if a filter is set",
  async assert => {
    await visit("/admin/site_settings");
    await fillIn("#setting-filter", "title");
    assert.equal(count(".row.setting"), 1);

    // navigate away to the "Dashboard" page
    await click(".nav.nav-pills li:nth-child(1) a");
    assert.equal(count(".row.setting"), 0);

    // navigate back to the "Settings" page
    await click(".nav.nav-pills li:nth-child(2) a");
    assert.equal(count(".row.setting"), 1);
  }
);
