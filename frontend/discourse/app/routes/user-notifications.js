import { notificationsLimit } from "discourse/lib/plugin-registries/notifications";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export { setNotificationsLimit } from "discourse/lib/plugin-registries/notifications";

export default class UserNotifications extends DiscourseRoute {
  controllerName = "user-notifications";
  queryParams = { filter: { refreshModel: true } };

  model(params) {
    const username = this.modelFor("user").get("username");

    if (
      this.get("currentUser.username") === username ||
      this.get("currentUser.admin")
    ) {
      return this.store.find("notification", {
        username,
        filter: params.filter,
        limit: notificationsLimit(),
      });
    }
  }

  setupController(controller) {
    super.setupController(...arguments);
    controller.set("user", this.modelFor("user"));
    this.controllerFor("user-activity").userActionType = -1;
  }

  titleToken() {
    return i18n("user.notifications");
  }
}
