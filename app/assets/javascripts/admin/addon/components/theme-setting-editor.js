import SiteSettingComponent from "./site-setting";

export default class extends SiteSettingComponent {
  _save() {
    return this.setting.updateSetting(
      this.model.id,
      this.get("buffered.value")
    );
  }
}
