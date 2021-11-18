import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,

  model() {
    return this.modelFor("user");
  },

  renderTemplate() {
    return this.render({ into: "user" });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  deactivate() {
    this._super(...arguments);
    this.render("preferences", { into: "user", controller: "preferences" });
  },

  setupController(controller, user) {
    controller.setProperties({
      model: user,
      newUsername: user.get("username"),
    });
  },
});
