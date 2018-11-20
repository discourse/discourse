import BufferedContent from "discourse/mixins/buffered-content";
import SettingComponent from "admin/mixins/setting-component";

export default Ember.Component.extend(BufferedContent, SettingComponent, {
  layoutName: "admin/templates/components/site-setting",
  _save() {
    return this.get("model").saveSettings(
      this.get("setting.setting"),
      this.get("buffered.value")
    );
  }
});
