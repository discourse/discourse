import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  controllerName: "user-notifications",
  renderTemplate() {
    this.render("user/notifications-index");
  },

  afterModel(model) {
    if (!model) {
      this.transitionTo("userNotifications.responses");
    }
  }
});
