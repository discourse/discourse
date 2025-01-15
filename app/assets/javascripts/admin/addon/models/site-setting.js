import EmberObject from "@ember/object";
import { alias } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import SettingObjectHelper from "admin/lib/setting-object-helper";

export default class SiteSetting extends EmberObject {
  static findAll(params = {}) {
    return ajax("/admin/site_settings", { data: params }).then(function (
      settings
    ) {
      // Group the results by category
      const categories = {};
      settings.site_settings.forEach(function (s) {
        if (!categories[s.category]) {
          categories[s.category] = [];
        }
        categories[s.category].pushObject(SiteSetting.create(s));
      });

      return Object.keys(categories).map(function (n) {
        return {
          nameKey: n,
          name: i18n("admin.site_settings.categories." + n),
          siteSettings: categories[n],
        };
      });
    });
  }

  static update(key, value, opts = {}) {
    const data = {};
    data[key] = value;

    if (opts["updateExistingUsers"] === true) {
      data["update_existing_user"] = true;
    }

    return ajax(`/admin/site_settings/${key}`, { type: "PUT", data });
  }

  settingObjectHelper = new SettingObjectHelper(this);

  @alias("settingObjectHelper.overridden") overridden;
  @alias("settingObjectHelper.computedValueProperty") computedValueProperty;
  @alias("settingObjectHelper.computedNameProperty") computedNameProperty;
  @alias("settingObjectHelper.validValues") validValues;
  @alias("settingObjectHelper.allowsNone") allowsNone;
  @alias("settingObjectHelper.anyValue") anyValue;

  @discourseComputed("setting")
  staffLogFilter(setting) {
    if (!setting) {
      return;
    }

    return {
      subject: setting,
      action_name: "change_site_setting",
    };
  }
}
