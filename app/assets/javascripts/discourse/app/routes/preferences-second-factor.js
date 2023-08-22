import RestrictedUserRoute from "discourse/routes/restricted-user";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default RestrictedUserRoute.extend({
  currentUser: service(),
  siteSettings: service(),

  model() {
    return this.modelFor("user");
  },

  setupController(controller, model) {
    controller.setProperties({ model, newUsername: model.username });
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

    if (
      transition.targetName === "preferences.second-factor" ||
      !this.currentUser ||
      this.currentUser.is_anonymous ||
      this.currentUser.second_factor_enabled ||
      (this.siteSettings.enforce_second_factor === "staff" &&
        !this.currentUser.staff) ||
      this.siteSettings.enforce_second_factor === "no"
    ) {
      return true;
    }

    transition.abort();
    return false;
  },
});
