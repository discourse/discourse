import SiteSettingComponent from "./site-setting";
import { alias } from "@ember/object/computed";

export default class ThemeTranslation extends SiteSettingComponent {
  @alias("translation") setting;
  type = "string";
  @alias("translation.key") settingName;

  _save() {
    return this.model.saveTranslation(
      this.get("translation.key"),
      this.get("buffered.value")
    );
  }
}
