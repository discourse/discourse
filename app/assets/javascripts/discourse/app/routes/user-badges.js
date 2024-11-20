import ViewingActionType from "discourse/mixins/viewing-action-type";
import UserBadge from "discourse/models/user-badge";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class UserBadges extends DiscourseRoute.extend(
  ViewingActionType
) {
  templateName = "user/badges";

  model() {
    return UserBadge.findByUsername(
      this.modelFor("user").get("username_lower"),
      { grouped: true }
    );
  }

  setupController() {
    super.setupController(...arguments);
    this.viewingActionType(-1);
  }

  titleToken() {
    return i18n("badges.title");
  }
}
