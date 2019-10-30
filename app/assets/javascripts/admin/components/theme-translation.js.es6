import { alias } from "@ember/object/computed";
import Component from "@ember/component";
import BufferedContent from "discourse/mixins/buffered-content";
import SettingComponent from "admin/mixins/setting-component";

export default Component.extend(BufferedContent, SettingComponent, {
  layoutName: "admin/templates/components/site-setting",
  setting: alias("translation"),
  type: "string",
  settingName: alias("translation.key"),

  _save() {
    return this.model.saveTranslation(
      this.get("translation.key"),
      this.get("buffered.value")
    );
  }
});
