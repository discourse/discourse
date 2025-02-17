import { i18n } from "discourse-i18n";
import AdminConfigWithSettingsRoute from "./admin-config-with-settings-route";

export default class AdminConfigFontsRoute extends AdminConfigWithSettingsRoute {
  titleToken() {
    return i18n("admin.appearance.sidebar_link.font_style");
  }
}
