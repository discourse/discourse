import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserNotificationsIndex extends DiscourseRoute {
  @service router;

  controllerName = "user-notifications";
  templateName = "user/notifications-index";

  titleToken() {
    return i18n("user.filters.all");
  }

  afterModel(model) {
    if (!model) {
      this.router.transitionTo("userNotifications.responses");
    }
  }
}
