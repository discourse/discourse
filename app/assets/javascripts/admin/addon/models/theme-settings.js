import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import Setting from "admin/mixins/setting-object";

export default class ThemeSettings extends EmberObject.extend(Setting) {
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
}
