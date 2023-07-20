import SiteSettingComponent from "./site-setting";
import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";

export default class extends SiteSettingComponent {
  @url("model.id", "/admin/themes/%@/setting") updateUrl;

  _save() {
    return ajax(this.updateUrl, {
      type: "PUT",
      data: {
        name: this.setting.setting,
        value: this.get("buffered.value"),
      },
    });
  }
}
