import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import PreloadStore from "discourse/lib/preload-store";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class AdminRoute extends DiscourseRoute {
  @service sidebarState;
  @service siteSettings;
  @service store;
  @service currentUser;
  @service adminSidebarStateManager;
  @tracked initialSidebarState;

  titleToken() {
    return I18n.t("admin_title");
  }

  activate() {
    this.adminSidebarStateManager.maybeForceAdminSidebar({
      onlyIfAlreadyActive: false,
    });

    this.controllerFor("application").setProperties({
      showTop: false,
    });

    const visiblePlugins = PreloadStore.get("visiblePlugins");
    if (visiblePlugins) {
      this.adminSidebarStateManager.keywords.admin_installed_plugins = {
        navigation: visiblePlugins.mapBy("name"),
      };
    }
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
