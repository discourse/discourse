import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,

  model() {
    return this.modelFor("user");
  },

  setupController(controller, model) {
    controller.reset();
    controller.setProperties({
      model,
      oldEmail: controller.new ? "" : model.email,
      newEmail: controller.new ? "" : model.email,
    });
  },

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.set("new", undefined);
    }
  },
});
