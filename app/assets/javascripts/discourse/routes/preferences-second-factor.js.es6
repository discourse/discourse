import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,

  model() {
    return this.modelFor("user");
  },

  renderTemplate() {
    return this.render({ into: "user" });
  },

  setupController(controller, model) {
    controller.setProperties({ model, newUsername: model.get("username") });
  },

  actions: {
    willTransition(transition) {
      this._super(...arguments);

      const controller = this.controllerFor("preferences/second-factor");
      const user = controller.get("currentUser");
      const settings = controller.get("siteSettings");

      if (
        transition.targetName === "preferences.second-factor" ||
        !user ||
        user.second_factor_enabled ||
        (settings.enforce_second_factor === "staff" && !user.staff) ||
        settings.enforce_second_factor === "no"
      ) {
        return true;
      }

      transition.abort();
      return false;
    }
  }
});
