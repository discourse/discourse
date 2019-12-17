import Component from "@ember/component";
import BufferedContent from "discourse/mixins/buffered-content";
import SettingComponent from "admin/mixins/setting-component";

export default Component.extend(BufferedContent, SettingComponent, {
  layoutName: "admin/templates/components/site-setting",

  _save() {
    return this.model
      .save({ [this.setting.setting]: this.convertNamesToIds() })
      .then(() => this.store.findAll("theme"));
  },

  convertNamesToIds() {
    return this.get("buffered.value")
      .split("|")
      .filter(Boolean)
      .map(themeName => {
        if (themeName !== "") {
          return this.setting.allThemes.find(theme => theme.name === themeName)
            .id;
        }
        return themeName;
      });
  }
});
