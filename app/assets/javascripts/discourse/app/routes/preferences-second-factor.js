import { action } from "@ember/object";
import { service } from "@ember/service";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesSecondFactor extends RestrictedUserRoute {
  @service currentUser;
  @service siteSettings;
  @service router;

  model() {
    return this.modelFor("user");
  }

  setupController(controller, model) {
    controller.setProperties({ model, newUsername: model.username });
    controller.set("loading", true);

    model
      .loadSecondFactorCodes()
      .then((response) => {
        if (response.error) {
          controller.set("errorMessage", response.error);
        } else if (response.unconfirmed_session) {
          this.router.transitionTo("preferences.security");
        } else {
          controller.setProperties({
            errorMessage: null,
            totps: response.totps,
            security_keys: response.security_keys,
          });
        }
      })
      .catch(controller.popupAjaxError)
      .finally(() => controller.set("loading", false));
  }

  @action
  willTransition(transition) {
    super.willTransition(...arguments);

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
  }
}
