import Component from "@ember/component";
import BufferedContent from "discourse/mixins/buffered-content";
import SettingComponent from "admin/mixins/setting-component";
import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";

export default Component.extend(BufferedContent, SettingComponent, {
  layoutName: "admin/templates/components/site-setting",
  updateUrl: url("model.id", "/admin/themes/%@/setting"),

  _save() {
    return ajax(this.updateUrl, {
      type: "PUT",
      data: {
        name: this.setting.setting,
        value: this.get("buffered.value")
      }
    });
  }
});
