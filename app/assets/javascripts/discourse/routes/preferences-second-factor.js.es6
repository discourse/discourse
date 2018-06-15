import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  model() {
    return this.modelFor("user");
  },

  renderTemplate() {
    return this.render({ into: "user" });
  },

  setupController(controller, model) {
    controller.setProperties({ model, newUsername: model.get("username") });
  }
});
