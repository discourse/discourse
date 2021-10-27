import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,

  setupController(controller, model) {
    this._super(...arguments);

    if (
      model.user_option &&
      "push_notifications_disabled" in model.user_option
    ) {
      controller.saveAttrNames.push("push_notifications_disabled");
    }
  },
});
