import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import SiteSetting from "admin/models/site-setting";

export default class ThemeSettings extends SiteSetting {
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
