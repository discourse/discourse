import UserActivityStreamRoute from "discourse/routes/user-activity-stream";
import { iconHTML } from "discourse-common/lib/icon-library";
import getURL from "discourse-common/lib/get-url";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";

export default UserActivityStreamRoute.extend({
  userActionType: null,

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
  },

  titleToken() {
    return I18n.t("user.filters.all");
  },
});
