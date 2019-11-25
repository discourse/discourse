import Component from "@ember/component";
import BufferedContent from "discourse/mixins/buffered-content";
import SettingComponent from "admin/mixins/setting-component";
import { ajax } from "discourse/lib/ajax";

export default Component.extend(BufferedContent, SettingComponent, {
  layoutName: "admin/templates/components/site-setting",

  _save() {
    return ajax(`/admin/themes/${this.model.id}`, {
      type: "PUT",
      data: {
        theme: {
          [this.setting.setting]: this.convertNamesToIds()
        }
      }
    }).then(() => {
      this.store.findAll("theme");
    });
  },

  convertNamesToIds() {
    return this.get("buffered.value")
      .split("|")
      .map(theme_name => {
        if (theme_name !== "") {
          return this.setting.allThemes.find(theme => theme.name === theme_name)
            .id;
        }
        return theme_name;
      });
  }
});
