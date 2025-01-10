import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigNotificationsRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.community.sidebar_link.notifications");
  }
}
