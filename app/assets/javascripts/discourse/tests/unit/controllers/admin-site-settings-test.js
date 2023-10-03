import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import SiteSetting from "admin/models/site-setting";

module("Unit | Controller | admin-site-settings", function (hooks) {
  setupTest(hooks);

  test("can perform fuzzy search", async function (assert) {
    const controller = this.owner.lookup("controller:admin-site-settings");
    const settings = await SiteSetting.findAll();

    let results = controller.performSearch("top_menu", settings);
    assert.deepEqual(results[0].siteSettings.length, 1);

    results = controller.performSearch("tmenu", settings);
    assert.deepEqual(results[0].siteSettings.length, 1);

    const settings2 = [
      {
        name: "Required",
        nameKey: "required",
        siteSettings: [
          SiteSetting.create({
            description: "",
            value: "",
            setting: "hpello world",
          }),
          SiteSetting.create({
            description: "",
            value: "",
            setting: "hello world",
          }),
          SiteSetting.create({
            description: "",
            value: "",
            setting: "digest_logo",
          }),
          SiteSetting.create({
            description: "",
            value: "",
            setting: "pending_users_reminder_delay_minutes",
          }),
          SiteSetting.create({
            description: "",
            value: "",
            setting: "min_personal_message_post_length",
          }),
        ],
      },
    ];

    results = controller.performSearch("hello world", settings2);
    assert.deepEqual(results[0].siteSettings.length, 2);
    // ensures hello world shows up before fuzzy hpello world
    assert.deepEqual(results[0].siteSettings[0].setting, "hello world");

    results = controller.performSearch("world", settings2);
    assert.deepEqual(results[0].siteSettings.length, 2);
    // ensures hello world shows up before fuzzy hpello world with "world" search
    assert.deepEqual(results[0].siteSettings[0].setting, "hello world");

    // ensures fuzzy search limiter is in place
    results = controller.performSearch("digest", settings2);
    assert.deepEqual(results[0].siteSettings.length, 1);
    assert.deepEqual(results[0].siteSettings[0].setting, "digest_logo");

    // ensures fuzzy search limiter doesn't limit too much
    results = controller.performSearch("min length", settings2);
    assert.strictEqual(results[0].siteSettings.length, 1);
    assert.strictEqual(
      results[0].siteSettings[0].setting,
      "min_personal_message_post_length"
    );
  });
});
