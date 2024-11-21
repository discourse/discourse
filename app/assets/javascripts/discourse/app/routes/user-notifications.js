import ViewingActionType from "discourse/mixins/viewing-action-type";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

const DEFAULT_LIMIT = 60;
let limit = DEFAULT_LIMIT;

export function setNotificationsLimit(newLimit) {
  limit = newLimit;
}

export default class UserNotifications extends DiscourseRoute.extend(
  ViewingActionType
) {
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
        limit,
      });
    }
  }

  setupController(controller) {
    super.setupController(...arguments);
    controller.set("user", this.modelFor("user"));
    this.viewingActionType(-1);
  }

  titleToken() {
    return i18n("user.notifications");
  }
}
