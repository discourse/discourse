import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ADMIN_NAV_MAP } from "discourse/lib/sidebar/admin-nav-map";
import {
  buildAdminSidebar,
  useAdminNavConfig,
} from "discourse/lib/sidebar/admin-sidebar";
import { resetPanelSections } from "discourse/lib/sidebar/custom-sections";
import { ADMIN_PANEL } from "discourse/lib/sidebar/panels";

// TODO (martin) (2024-02-01) Remove this experimental UI.
export default class AdminConfigAreaSidebarExperiment extends Component {
  @service adminSidebarStateManager;
  @service toasts;
  @service router;
  @tracked editedNavConfig;

  validRouteNames = new Set();

  get defaultAdminNav() {
    return JSON.stringify(ADMIN_NAV_MAP, null, 2);
  }

  get exampleJson() {
    return JSON.stringify(
      {
        name: "section-name",
        text: "Section Name",
        links: [
          {
            name: "admin-revamp",
            route: "admin-revamp",
            routeModels: [123],
            text: "Revamp",
            href: "https://forum.site.com/t/123",
            icon: "rocket",
          },
        ],
      },
      null,
      2
    );
  }

  @action
  loadDefaultNavConfig() {
    const savedConfig = this.adminSidebarStateManager.navConfig;
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

    let invalidRoutes = [];
    config.forEach((section) => {
      section.links.forEach((link) => {
        if (!link.route) {
          return;
        }

        if (this.validRouteNames.has(link.route)) {
          return;
        }

        // Using the private `_routerMicrolib` is not ideal, but Ember doesn't provide
        // any other way for us to easily check for route validity.
        try {
          // eslint-disable-next-line ember/no-private-routing-service
          this.router._router._routerMicrolib.recognizer.handlersFor(
            link.route
          );
          this.validRouteNames.add(link.route);
        } catch (err) {
          // eslint-disable-next-line no-console
          console.debug("[AdminSidebarExperiment]", err);
          invalidRoutes.push(link.route);
        }
      });
    });

    if (invalidRoutes.length) {
      this.toasts.error({
        duration: 3000,
        data: {
          message: `There was an error with one or more of the routes provided: ${invalidRoutes.join(
            ", "
          )}`,
        },
      });
      return;
    }

    this.#saveConfig(config);
  }

  #saveConfig(config) {
    this.adminSidebarStateManager.navConfig = config;
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
