import { action } from "@ember/object";
import { service } from "@ember/service";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesProfile extends RestrictedUserRoute {
  @service currentUser;

  setupController(controller, model) {
    controller.set("model", model);
  }

  @action
  willTransition(transition) {
    super.willTransition(...arguments);

    if (
      this.currentUser?.needs_required_fields_check &&
      !transition?.to.name.startsWith("admin")
    ) {
      transition.abort();
      return false;
    }

    return true;
  }
}
