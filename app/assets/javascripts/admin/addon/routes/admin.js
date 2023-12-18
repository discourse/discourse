import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/services/sidebar-state";
import I18n from "discourse-i18n";

export default class AdminRoute extends DiscourseRoute {
  @service sidebarState;
  @service siteSettings;

  titleToken() {
    return I18n.t("admin_title");
  }

  activate() {
    if (this.siteSettings.enable_admin_sidebar_navigation) {
      this.sidebarState.setPanel(ADMIN_PANEL);
      this.sidebarState.setSeparatedMode();
      this.sidebarState.hideSwitchPanelButtons();
    }

    this.controllerFor("application").setProperties({
      showTop: false,
    });
  }

  deactivate(transition) {
    this.controllerFor("application").set("showTop", true);

    if (this.siteSettings.enable_admin_sidebar_navigation) {
      if (!transition?.to.name.startsWith("admin")) {
        this.sidebarState.setPanel(MAIN_PANEL);
      }
    }
  }
}
