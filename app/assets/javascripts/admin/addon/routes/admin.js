import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminRoute extends DiscourseRoute {
  @service sidebarState;
  @service siteSettings;
  @service store;
  @service currentUser;
  @service adminSidebarStateManager;
  @tracked initialSidebarState;

  titleToken() {
    return i18n("admin_title");
  }

  activate() {
    this.adminSidebarStateManager.maybeForceAdminSidebar({
      onlyIfAlreadyActive: false,
    });

    this.controllerFor("application").setProperties({
      showTop: false,
    });
  }

  deactivate(transition) {
    this.controllerFor("application").set("showTop", true);

    if (this.adminSidebarStateManager.currentUserUsingAdminSidebar) {
      if (!transition?.to.name.startsWith("admin")) {
        this.adminSidebarStateManager.stopForcingAdminSidebar();
      }
    }
  }
}
