import SiteSettingComponent from "./site-setting";

export default class ThemeSettingRelativesSelectorComponent extends SiteSettingComponent {
  _save() {
    return this.model
      .save({ [this.setting.setting]: this.convertNamesToIds() })
      .then(() => this.store.findAll("theme"));
  }

  convertNamesToIds() {
    return this.get("buffered.value")
      .split("|")
      .filter(Boolean)
      .map((themeName) => {
        if (themeName !== "") {
          return this.setting.allThemes.find(
            (theme) => theme.name === themeName
          ).id;
        }
        return themeName;
      });
  }
}
