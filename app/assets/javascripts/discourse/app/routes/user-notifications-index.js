import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  controllerName: "user-notifications",
  templateName: "user/notifications-index",

  afterModel(model) {
    if (!model) {
      this.transitionTo("userNotifications.responses");
    }
  },
});
