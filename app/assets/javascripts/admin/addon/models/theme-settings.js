import EmberObject from "@ember/object";
import { alias } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import SettingObjectHelper from "admin/lib/setting-object-helper";

export default class ThemeSettings extends EmberObject {
  settingObjectHelper = new SettingObjectHelper(this);

  @alias("settingObjectHelper.overridden") overridden;
  @alias("settingObjectHelper.computedValueProperty") computedValueProperty;
  @alias("settingObjectHelper.computedNameProperty") computedNameProperty;
  @alias("settingObjectHelper.validValues") validValues;
  @alias("settingObjectHelper.allowsNone") allowsNone;
  @alias("settingObjectHelper.anyValue") anyValue;

  updateSetting(themeId, newValue) {
    if (this.objects_schema) {
      newValue = JSON.stringify(newValue);
    }

    return ajax(`/admin/themes/${themeId}/setting`, {
      type: "PUT",
      data: {
        name: this.setting,
        value: newValue,
      },
    });
  }

  loadMetadata(themeId) {
    return ajax(
      `/admin/themes/${themeId}/objects_setting_metadata/${this.setting}.json`
    )
      .then((result) => this.set("metadata", result))
      .catch(popupAjaxError);
  }
}
