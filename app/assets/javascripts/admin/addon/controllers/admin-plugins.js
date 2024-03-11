import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminPluginsController extends Controller {
  @service router;

  get adminRoutes() {
    return this.allAdminRoutes.filter((route) =>
      this.routeExists(route.full_location)
    );
  }

  get brokenAdminRoutes() {
    return this.allAdminRoutes.filter(
      (route) => !this.routeExists(route.full_location)
    );
  }

  get allAdminRoutes() {
    return this.model
      .filter((plugin) => plugin?.enabled)
      .map((plugin) => {
        return plugin.adminRoute;
      })
      .filter(Boolean);
  }

  routeExists(routeName) {
    try {
      this.router.urlFor(routeName);
      return true;
    } catch (e) {
      return false;
    }
  }
}
