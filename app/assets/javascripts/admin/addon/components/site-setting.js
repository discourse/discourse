import { readOnly } from "@ember/object/computed";
import BufferedContent from "discourse/mixins/buffered-content";
import Component from "@ember/component";
import SettingComponent from "admin/mixins/setting-component";
import SiteSetting from "admin/models/site-setting";

export default class SiteSettingComponent extends Component.extend(
  BufferedContent,
  SettingComponent
) {
  updateExistingUsers = null;

  @readOnly("setting.staffLogFilter") staffLogFilter;
  _save() {
    const setting = this.buffered;
    return SiteSetting.update(setting.get("setting"), setting.get("value"), {
      updateExistingUsers: this.updateExistingUsers,
    });
  }
}
