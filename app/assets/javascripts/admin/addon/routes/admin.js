import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import {
  ADMIN_PANEL,
  COMBINED_MODE,
  MAIN_PANEL,
  SEPARATED_MODE,
} from "discourse/lib/sidebar/panels";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class AdminRoute extends DiscourseRoute {
  @service sidebarState;
  @service siteSettings;
  @service currentUser;
  @tracked initialSidebarState;

  titleToken() {
    return I18n.t("admin_title");
  }

  activate() {
    if (this.currentUser.use_admin_sidebar) {
      this.initialSidebarState = {
        mode: this.sidebarState.mode,
        displaySwitchPanelButtons: this.sidebarState.displaySwitchPanelButtons,
      };

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

    if (this.currentUser.use_admin_sidebar) {
      if (!transition?.to.name.startsWith("admin")) {
        if (this.initialSidebarState.mode === SEPARATED_MODE) {
          this.sidebarState.setSeparatedMode();
        } else if (this.initialSidebarState.mode === COMBINED_MODE) {
          this.sidebarState.setCombinedMode();
        }

        if (this.initialSidebarState.displaySwitchPanelButtons) {
          this.sidebarState.showSwitchPanelButtons();
        } else {
          this.sidebarState.hideSwitchPanelButtons();
        }

        this.sidebarState.setPanel(MAIN_PANEL);
      }
    }
  }
}
