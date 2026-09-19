import Controller from "@ember/controller";
import { service } from "@ember/service";
import { adminRouteValid } from "discourse/lib/admin-utilities";

export default class AdminPluginsController extends Controller {
  @service adminPluginNavManager;
  @service router;

  get brokenAdminRoutes() {
    return this.allAdminRoutes.filter(
      (route) => !adminRouteValid(this.router, route)
    );
  }

  get allAdminRoutes() {
    return this.model
      .filter(
        (plugin) =>
          plugin?.enabled &&
          plugin?.adminRoute &&
          !plugin?.adminRoute?.auto_generated
      )
      .map((plugin) => {
        return Object.assign(plugin.adminRoute, { plugin_id: plugin.id });
      });
  }

  get showBreadcrumbs() {
    return (
      !this.adminPluginNavManager.viewingPluginsList &&
      !this.adminPluginNavManager.currentPlugin
    );
  }

  // Plugins on the show route get their name breadcrumb from
  // AdminPluginConfigPage. Ones still routing to their own admin templates
  // have to be matched against the route they registered.
  get currentLegacyPlugin() {
    const currentRouteName = this.router.currentRouteName;

    if (!currentRouteName) {
      return null;
    }

    return this.model.find((plugin) => {
      const route = plugin.adminRoute;

      if (!route || route.use_new_show_route) {
        return false;
      }

      const namespace = `adminPlugins.${route.location.split(".")[0]}`;
      return (
        currentRouteName === namespace ||
        currentRouteName.startsWith(`${namespace}.`)
      );
    });
  }
}
