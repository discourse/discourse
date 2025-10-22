import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigThemeSiteSettings extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.theme_site_settings.title");
  }
}
