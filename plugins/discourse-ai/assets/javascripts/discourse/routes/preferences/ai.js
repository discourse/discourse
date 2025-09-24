import { service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesAiRoute extends RestrictedUserRoute {
  @service siteSettings;

  setupController(controller, user) {
    if (!this.siteSettings.discourse_ai_enabled) {
      return this.router.transitionTo(`discovery.${defaultHomepage()}`);
    }

    controller.set("model", user);
  }
}
