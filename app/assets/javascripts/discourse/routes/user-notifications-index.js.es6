export default Discourse.Route.extend({
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
