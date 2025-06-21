import SiteSettingComponent from "./site-setting";

export default class extends SiteSettingComponent {
  _save() {
    return this.setting.updateSetting(
      this.args.model.id,
      this.buffered.get("value")
    );
  }
}
