import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigSiteAdminSettingsRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.site_admin.title");
  }
}
