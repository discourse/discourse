import Controller from "@ember/controller";
import { service } from "@ember/service";
import { adminRouteValid } from "discourse/lib/admin-utilities";

export default class AdminPluginsController extends Controller {
  @service adminPluginNavManager;
  @service router;

  get adminRoutes() {
    return this.allAdminRoutes.filter((route) =>
      adminRouteValid(this.router, route)
    );
  }

  get brokenAdminRoutes() {
    return this.allAdminRoutes.filter(
      (route) => !adminRouteValid(this.router, route)
    );
  }

  // NOTE: See also AdminPluginsIndexController, there is some duplication here
  // while we convert plugins to use_new_show_route
  get allAdminRoutes() {
    return this.model
      .filter((plugin) => plugin?.enabled && plugin?.adminRoute)
      .map((plugin) => {
        return Object.assign(plugin.adminRoute, { plugin_id: plugin.id });
      });
  }

  get showTopNav() {
    return (
      !this.adminPluginNavManager.viewingPluginsList &&
      (!this.adminPluginNavManager.currentPlugin ||
        this.adminPluginNavManager.isSidebarMode)
    );
  }
}
