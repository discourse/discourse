import { service } from "@ember/service";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import DiscourseURL from "discourse/lib/url";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

// DEPRECATED: (martin) This route is deprecated and will be removed in the near future.
export default class AdminRoute extends DiscourseRoute {
  @service siteSettings;
  @service currentUser;
  @service sidebarState;
  @service adminSidebarStateManager;

  titleToken() {
    return I18n.t("admin_title");
  }

  activate() {
    if (!this.currentUser.use_admin_sidebar) {
      return DiscourseURL.redirectTo("/admin");
    }

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
        this.sidebarState.setPanel(MAIN_PANEL);
      }
    }
  }
}
