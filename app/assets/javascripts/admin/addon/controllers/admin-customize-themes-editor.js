import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";

export default class AdminCustomizeThemesEditorController extends Controller {
  get component() {
    const componentPath = this.settingObject?.editor_component;
    if (!componentPath) {
      // TODO: do something
    }
    return require(`discourse/theme-${this.theme.id}/${componentPath}`).default;
  }

  get settingObject() {
    return this.theme.settings.find(
      (setting) => setting.setting === this.settingName
    );
  }

  get saveFunction() {
    return (data) => {
      return ajax(`/admin/themes/${this.theme.id}/setting`, {
        type: "PUT",
        data: {
          name: this.settingName,
          value: JSON.stringify(data),
        },
      });
    };
  }

  get data() {
    if (this.settingObject.value) {
      return JSON.parse(this.settingObject.value);
    } else {
      return null;
    }
  }
}
