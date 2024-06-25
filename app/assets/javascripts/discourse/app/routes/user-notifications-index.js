import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class UserNotificationsIndex extends DiscourseRoute {
  @service router;

  controllerName = "user-notifications";
  templateName = "user/notifications-index";

  titleToken() {
    return I18n.t("user.filters.all");
  }

  afterModel(model) {
    if (!model) {
      this.router.transitionTo("userNotifications.responses");
    }
  }
}
