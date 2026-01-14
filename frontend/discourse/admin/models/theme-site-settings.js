import SiteSetting from "discourse/admin/models/site-setting";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class ThemeSiteSettings extends SiteSetting {
  async updateSetting(themeId, newValue) {
    try {
      return ajax(`/admin/themes/${themeId}/site-setting`, {
        type: "PUT",
        data: {
          name: this.setting,
          value: newValue,
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
