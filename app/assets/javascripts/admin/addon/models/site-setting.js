import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { alias } from "@ember/object/computed";
import BufferedProxy from "ember-buffered-proxy/proxy";
import { ajax } from "discourse/lib/ajax";
import discourseComputed, { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import {
  DEFAULT_USER_PREFERENCES,
  SITE_SETTING_REQUIRES_CONFIRMATION_TYPES,
} from "admin/lib/constants";
import SettingObjectHelper from "admin/lib/setting-object-helper";

const AUTO_REFRESH_ON_SAVE = [
  "logo",
  "mobile_logo",
  "base_font",
  "heading_font",
  "default_text_size",
];

export default class SiteSetting extends EmberObject {
  static async findAll(params = {}) {
    let settings = await ajax("/admin/site_settings", { data: params });
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
  }

  static findByName(name) {
    return ajax("/admin/site_settings", {
      data: {
        names: [name],
      },
    }).then(function (settings) {
      const setting = settings.site_settings.find((s) => s.setting === name);
      return SiteSetting.create(setting);
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

  static bulkUpdate(settings) {
    return ajax(`/admin/site_settings/bulk_update.json`, {
      type: "PUT",
      data: { settings },
    });
  }

  @tracked isSaving = false;
  @tracked validationMessage = null;
  updateExistingUsers = false;

  settingObjectHelper = new SettingObjectHelper(this);

  @alias("settingObjectHelper.overridden") overridden;
  @alias("settingObjectHelper.computedValueProperty") computedValueProperty;
  @alias("settingObjectHelper.computedNameProperty") computedNameProperty;
  @alias("settingObjectHelper.validValues") validValues;
  @alias("settingObjectHelper.allowsNone") allowsNone;
  @alias("settingObjectHelper.anyValue") anyValue;

  constructor() {
    super(...arguments);
    this.buffered = BufferedProxy.create({ content: this });
  }

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

  get requiresConfirmation() {
    return (
      this.requires_confirmation ===
      SITE_SETTING_REQUIRES_CONFIRMATION_TYPES.simple
    );
  }

  get requiresReload() {
    return AUTO_REFRESH_ON_SAVE.includes(this.setting);
  }

  get affectsExistingUsers() {
    return DEFAULT_USER_PREFERENCES.includes(this.setting);
  }

  @bind
  setUpdateExistingUsers(value) {
    this.updateExistingUsers = value;
  }
}
