import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import {
  buildAdminSidebar,
  useAdminNavConfig,
} from "discourse/instance-initializers/admin-sidebar";
import { ADMIN_NAV_MAP } from "discourse/lib/sidebar/admin-nav-map";
import { resetPanelSections } from "discourse/lib/sidebar/custom-sections";
import { ADMIN_PANEL } from "discourse/services/sidebar-state";

export default class AdminConfigAreaSidebarExperiment extends Component {
  @service adminSidebarExperimentStateManager;
  @service toasts;
  @tracked editedNavConfig;

  get defaultAdminNav() {
    return JSON.stringify(ADMIN_NAV_MAP, null, 2);
  }

  @action
  loadDefaultNavConfig() {
    const savedConfig = this.adminSidebarExperimentStateManager.navConfig;
    this.editedNavConfig = savedConfig
      ? JSON.stringify(savedConfig, null, 2)
      : this.defaultAdminNav;
  }

  @action
  resetToDefault() {
    this.editedNavConfig = this.defaultAdminNav;
    this.#saveConfig(ADMIN_NAV_MAP);
  }

  @action
  applyConfig() {
    let config = null;
    try {
      config = JSON.parse(this.editedNavConfig);
    } catch {
      this.toasts.error({
        duration: 3000,
        data: {
          message: "There was an error, make sure the structure is valid JSON.",
        },
      });
      return;
    }

    this.#saveConfig(config);
  }

  #saveConfig(config) {
    this.adminSidebarExperimentStateManager.navConfig = config;
    resetPanelSections(
      ADMIN_PANEL,
      useAdminNavConfig(config),
      buildAdminSidebar
    );
    this.toasts.success({
      duration: 3000,
      data: { message: "Sidebar navigation applied successfully!" },
    });
  }
}
