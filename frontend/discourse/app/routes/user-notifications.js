import { service } from "@ember/service";
import notificationHistoryTypeFilters from "discourse/lib/notification-history-type-filters";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

const DEFAULT_LIMIT = 60;
let limit = DEFAULT_LIMIT;

export function setNotificationsLimit(newLimit) {
  limit = newLimit;
}

export default class UserNotifications extends DiscourseRoute {
  @service site;
  @service siteSettings;

  controllerName = "user-notifications";
  queryParams = {
    filter: { refreshModel: true },
    notificationType: { refreshModel: true },
  };

  model(params) {
    const username = this.modelFor("user").get("username");

    if (
      this.get("currentUser.username") === username ||
      this.get("currentUser.admin")
    ) {
      const query = { username, filter: params.filter, limit };
      if (
        this.siteSettings.enable_notification_history_type_filter &&
        params.notificationType
      ) {
        const types = notificationHistoryTypeFilters(
          this.site.notification_types
        ).get(params.notificationType);
        if (types) {
          query.filter_by_types = types.join(",");
        }
      }
      return this.store.find("notification", query);
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
