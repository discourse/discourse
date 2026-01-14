import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigLogoRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.logo.title");
  }
}
