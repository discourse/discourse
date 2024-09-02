import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminPluginsController extends Controller {
  @service adminPluginNavManager;
  @service router;

  get adminRoutes() {
    return this.allAdminRoutes.filter((route) => this.routeExists(route));
  }

  get brokenAdminRoutes() {
    return this.allAdminRoutes.filter((route) => !this.routeExists(route));
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

  routeExists(route) {
    try {
      if (route.use_new_show_route) {
        this.router.urlFor(route.full_location, route.location);
      } else {
        this.router.urlFor(route.full_location);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
