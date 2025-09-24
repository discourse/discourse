import { htmlSafe } from "@ember/template";
import getURL from "discourse/lib/get-url";
import { iconHTML } from "discourse/lib/icon-library";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import { i18n } from "discourse-i18n";

export default class UserActivityIndex extends UserActivityStreamRoute {
  userActionType = null;

  emptyState() {
    const user = this.modelFor("user");

    const title = i18n("user_activity.no_activity_title");
    let body = "";
    if (this.isCurrentUser(user)) {
      body = htmlSafe(
        i18n("user_activity.no_activity_body", {
          topUrl: getURL("/top"),
          categoriesUrl: getURL("/categories"),
          preferencesUrl: getURL("/my/preferences"),
          heartIcon: iconHTML("heart"),
        })
      );
    }

    return { title, body };
  }

  titleToken() {
    return i18n("user.filters.all");
  }
}
