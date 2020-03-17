import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,

  model: function() {
    return this.modelFor("user");
  },

  renderTemplate: function() {
    this.render({ into: "user" });
  },

  setupController: function(controller, model) {
    controller.reset();
    controller.setProperties({ model: model, newEmail: model.get("email") });
  },

  // A bit odd, but if we leave to /preferences we need to re-render that outlet
  deactivate: function() {
    this._super(...arguments);
    this.render("preferences", { into: "user", controller: "preferences" });
  }
});
