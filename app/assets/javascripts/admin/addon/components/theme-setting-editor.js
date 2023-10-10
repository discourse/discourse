import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";
import SiteSettingComponent from "./site-setting";

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
