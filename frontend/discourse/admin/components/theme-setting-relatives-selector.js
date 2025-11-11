import SiteSettingComponent from "./site-setting";

export default class ThemeSettingRelativesSelectorComponent extends SiteSettingComponent {
  _save() {
    return this.args.model.save({
      [this.args.setting.setting]: this.convertNamesToIds(),
    });
  }

  convertNamesToIds() {
    return this.buffered
      .get("value")
      .split("|")
      .filter(Boolean)
      .map((themeName) => {
        if (themeName !== "") {
          return this.args.setting.allThemes.find(
            (theme) => theme.name === themeName
          ).id;
        }
        return themeName;
      });
  }
}
