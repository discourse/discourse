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
        ],
      },
    ];

    results = controller.performSearch("hello world", settings2);
    assert.deepEqual(results[0].siteSettings.length, 2);
    // ensures hello world shows up before fuzzy hpello world
    assert.deepEqual(results[0].siteSettings[0].setting, "hello world");
  });
});
