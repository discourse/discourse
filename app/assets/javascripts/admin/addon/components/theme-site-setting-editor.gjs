import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import SiteSettingComponent from "./site-setting";

export default class ThemeSiteSettingEditor extends SiteSettingComponent {
  @service toasts;

  _save() {
    return this.setting
      .updateSetting(this.args.model.id, this.buffered.get("value"))
      .then(() => {
        this.toasts.success({
          data: {
            message: i18n("admin.customize.theme.theme_site_setting_saved"),
          },
          duration: "short",
        });
      });
  }
}
