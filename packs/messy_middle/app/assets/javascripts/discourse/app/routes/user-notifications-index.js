import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default DiscourseRoute.extend({
  controllerName: "user-notifications",
  renderTemplate() {
    this.render("user/notifications-index");
  },

  titleToken() {
    return I18n.t("user.filters.all");
  },

  afterModel(model) {
    if (!model) {
      this.transitionTo("userNotifications.responses");
    }
  },
});
