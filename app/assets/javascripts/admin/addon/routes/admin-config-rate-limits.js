import { i18n } from "discourse-i18n";
import AdminConfigWithSettingsRoute from "./admin-config-with-settings-route";

export default class AdminConfigRateLimitsRoute extends AdminConfigWithSettingsRoute {
  titleToken() {
    return i18n("admin.advanced.sidebar_link.rate_limits");
  }
}
