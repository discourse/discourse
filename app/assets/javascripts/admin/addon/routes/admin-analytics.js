import { i18n } from "discourse-i18n";
import AdminConfigWithSettingsRoute from "./admin-config-with-settings-route";

export default class AdminAnalyticsRoute extends AdminConfigWithSettingsRoute {
  titleToken() {
    return i18n("admin.config.analytics.title");
  }
}
