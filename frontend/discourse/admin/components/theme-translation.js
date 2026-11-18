import { cached } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import SiteSettingComponent from "./site-setting.gjs";

export default class ThemeTranslation extends SiteSettingComponent {
  type = "string";
  trackChanges = false;

  get setting() {
    return this.args.translation;
  }

  @cached
  get definition() {
    const { key } = this.args.translation;

    return { ...this.args.translation.definition, key, label: key };
  }

  get settingName() {
    return this.args.translation.key;
  }

  _save() {
    const translations = {
      [this.args.translation.key]: this.buffered.get("value"),
    };

    return ajax(getURL(`/admin/themes/${this.args.model.id}`), {
      type: "PUT",
      data: { theme: { translations, locale: this.args.model.locale } },
    });
  }
}
