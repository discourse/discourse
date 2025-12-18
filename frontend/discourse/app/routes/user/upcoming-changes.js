import { service } from "@ember/service";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class UserUpcomingChanges extends RestrictedUserRoute {
  @service siteSettings;

  beforeModel() {
    if (!this.siteSettings.enable_upcoming_changes) {
      this.router.replaceWith("discovery");
    }
  }

  setupController(controller, user) {
    controller.setProperties({ model: user });
  }
}
