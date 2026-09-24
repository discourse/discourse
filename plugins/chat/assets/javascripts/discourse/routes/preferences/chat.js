import { service } from "@ember/service";
import { homepageNavigationDestination } from "discourse/lib/homepage-router-overrides";
import RestrictedUserRoute from "discourse/routes/restricted-user";

export default class PreferencesChatRoute extends RestrictedUserRoute {
  @service router;
  @service siteSettings;
  @service currentUser;

  showFooter = true;

  setupController(controller, user) {
    if (
      !this.siteSettings.chat_enabled ||
      (!user.can_chat && !this.currentUser?.admin)
    ) {
      return this.router.transitionTo(homepageNavigationDestination());
    }

    controller.set("model", user);
  }
}
