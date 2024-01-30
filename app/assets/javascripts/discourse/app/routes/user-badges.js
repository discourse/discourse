import ViewingActionType from "discourse/mixins/viewing-action-type";
import UserBadge from "discourse/models/user-badge";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default DiscourseRoute.extend(ViewingActionType, {
  templateName: "user/badges",

  model() {
    return UserBadge.findByUsername(
      this.modelFor("user").get("username_lower"),
      { grouped: true }
    );
  },

  setupController() {
    this._super(...arguments);
    this.viewingActionType(-1);
  },

  titleToken() {
    return I18n.t("badges.title");
  },
});
