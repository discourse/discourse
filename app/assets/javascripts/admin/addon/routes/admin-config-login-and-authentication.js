import { i18n } from "discourse-i18n";
import AdminConfigWithSettingsRoute from "./admin-config-with-settings-route";

export default class AdminConfigLoginAndAuthenticationRoute extends AdminConfigWithSettingsRoute {
  titleToken() {
    return i18n("admin.config.login_and_authentication.title");
  }
}
