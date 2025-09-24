import { service } from "@ember/service";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesSecondFactor extends RestrictedUserRoute {
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
}
