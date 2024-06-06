import { htmlSafe } from "@ember/template";
import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import getURL from "discourse-common/lib/get-url";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "discourse-i18n";

export default class UserActivityIndex extends UserActivityStreamRoute {
  userActionType = null;

  emptyState() {
    const user = this.modelFor("user");

    const title = I18n.t("user_activity.no_activity_title");
    let body = "";
    if (this.isCurrentUser(user)) {
      body = htmlSafe(
        I18n.t("user_activity.no_activity_body", {
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
    return I18n.t("user.filters.all");
  }
}
