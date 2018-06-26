import BufferedContent from "discourse/mixins/buffered-content";
import SiteSetting from "admin/models/site-setting";
import SettingComponent from "admin/mixins/setting-component";

export default Ember.Component.extend(BufferedContent, SettingComponent, {
  _save() {
    const setting = this.get("buffered");
    return SiteSetting.update(setting.get("setting"), setting.get("value"));
  }
});
