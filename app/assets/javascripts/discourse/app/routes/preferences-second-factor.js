import RestrictedUserRoute from "discourse/routes/restricted-user";
import { action } from "@ember/object";

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
    controller.set("loading", true);

    model
      .loadSecondFactorCodes("")
      .then((response) => {
        if (response.error) {
          controller.set("errorMessage", response.error);
        } else {
          controller.setProperties({
            errorMessage: null,
            loaded: !response.password_required,
            dirty: !!response.password_required,
            totps: response.totps,
            security_keys: response.security_keys,
          });
        }
      })
      .catch(controller.popupAjaxError)
      .finally(() => controller.set("loading", false));
  },

  @action
  willTransition(transition) {
    this._super(...arguments);

    const controller = this.controllerFor("preferences/second-factor");
    const user = controller.get("currentUser");
    const settings = controller.get("siteSettings");

    if (
      transition.targetName === "preferences.second-factor" ||
      !user ||
      user.is_anonymous ||
      user.second_factor_enabled ||
      (settings.enforce_second_factor === "staff" && !user.staff) ||
      settings.enforce_second_factor === "no"
    ) {
      return true;
    }

    transition.abort();
    return false;
  },
});
