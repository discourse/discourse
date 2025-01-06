import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigNavigationRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.appearance.sidebar_link.navigation");
  }
}
