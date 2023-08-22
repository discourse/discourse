import SiteSettingComponent from "./site-setting";
import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";
import { alias } from "@ember/object/computed";

export default class ThemeTranslation extends SiteSettingComponent {
  @alias("translation") setting;
  @alias("translation.key") settingName;
  @url("model.id", "/admin/themes/%@") updateUrl;

  type = "string";

  _save() {
    const translations = {
      [this.get("translation.key")]: this.get("buffered.value"),
    };

    return ajax(this.updateUrl, {
      type: "PUT",
      data: { theme: { translations } },
    });
  }
}
