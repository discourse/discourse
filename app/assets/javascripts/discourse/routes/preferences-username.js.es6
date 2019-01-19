import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,

  model: function() {
    return this.modelFor("user");
  },

  renderTemplate: function() {
    return this.render({ into: "user" });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  deactivate: function() {
    this._super(...arguments);
    this.render("preferences", { into: "user", controller: "preferences" });
  },

  setupController: function(controller, user) {
    controller.setProperties({
      model: user,
      newUsername: user.get("username")
    });
  }
});
