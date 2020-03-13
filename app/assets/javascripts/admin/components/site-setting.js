import Component from "@ember/component";
import BufferedContent from "discourse/mixins/buffered-content";
import SiteSetting from "admin/models/site-setting";
import SettingComponent from "admin/mixins/setting-component";

export default Component.extend(BufferedContent, SettingComponent, {
  updateExistingUsers: null,

  _save() {
    const setting = this.buffered;
    return SiteSetting.update(setting.get("setting"), setting.get("value"), {
      updateExistingUsers: this.updateExistingUsers
    });
  }
});
