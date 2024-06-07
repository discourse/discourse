import { action } from "@ember/object";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesProfile extends RestrictedUserRoute {
  setupController(controller, model) {
    controller.set("model", model);
  }

  @action
  willTransition(transition) {
    super.willTransition(...arguments);

    if (
      this.controllerFor("preferences.profile").get(
        "showEnforcedRequiredFieldsNotice"
      )
    ) {
      transition.abort();
      return false;
    }

    return true;
  }
}
