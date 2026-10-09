import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SiteSettingFilter from "discourse/admin/lib/site-setting-filter";
import SiteSetting from "discourse/admin/models/site-setting";

module("Unit | Lib | SiteSettingFilter", function (hooks) {
  setupTest(hooks);

  test("lists an inline dependent's parent once when they are in different categories", function (assert) {
    const parent = SiteSetting.create({
      setting: "highlight_scope",
      description: "Choose a scope.",
      value: "include",
    });
    const dependent = SiteSetting.create({
      setting: "highlight_categories",
      description: "Choose categories.",
      value: "",
      depends_on: ["highlight_scope"],
      depends_on_values: { highlight_scope: ["include"] },
      depends_behavior: "hidden",
      dependent_setting_display: "inline",
    });
    const filter = new SiteSettingFilter([
      { nameKey: "basic", siteSettings: [parent] },
      { nameKey: "plugins", siteSettings: [dependent] },
    ]);

    const [all, ...categories] = filter.filterSettings("highlight");

    assert.deepEqual(
      all.siteSettings.map((setting) => setting.setting),
      ["highlight_scope"]
    );
    assert.deepEqual(
      categories.map((category) => category.nameKey),
      ["basic"]
    );
  });
});
