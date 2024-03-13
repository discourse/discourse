import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import PreloadStore from "discourse/lib/preload-store";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";
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
    if (this.currentUser.use_admin_sidebar) {
      this.sidebarState.setPanel(ADMIN_PANEL);
      this.sidebarState.setSeparatedMode();
      this.sidebarState.hideSwitchPanelButtons();
    }

    this.controllerFor("application").setProperties({
      showTop: false,
    });

    this.adminSidebarStateManager.keywords.admin_installed_plugins = {
      navigation: PreloadStore.get("visiblePlugins").mapBy("name"),
    };
  }

  deactivate(transition) {
    this.controllerFor("application").set("showTop", true);

    if (this.currentUser.use_admin_sidebar) {
      if (!transition?.to.name.startsWith("admin")) {
        this.sidebarState.setPanel(MAIN_PANEL);
      }
    }
  }
}
