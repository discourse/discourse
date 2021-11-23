import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,

  model() {
    return this.modelFor("user");
  },

  renderTemplate() {
    this.render({ into: "user" });
  },

  setupController(controller, model) {
    controller.reset();
    controller.setProperties({
      model,
      oldEmail: controller.new ? "" : model.get("email"),
      newEmail: controller.new ? "" : model.get("email"),
    });
  },

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.set("new", undefined);
    }
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  deactivate() {
    this._super(...arguments);
    this.render("preferences", { into: "user", controller: "preferences" });
  },
});
