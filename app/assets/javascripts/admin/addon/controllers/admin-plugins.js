import Controller from "@ember/controller";
import { inject as service } from "@ember/service";

export default Controller.extend({
  router: service(),

  get adminRoutes() {
    return this.allAdminRoutes.filter((r) => this.routeExists(r.full_location));
  },

  get brokenAdminRoutes() {
    return this.allAdminRoutes.filter(
      (r) => !this.routeExists(r.full_location)
    );
  },

  get allAdminRoutes() {
    return this.model
      .filter((p) => p?.enabled)
      .map((p) => {
        return p.admin_route;
      })
      .filter(Boolean);
  },

  routeExists(routeName) {
    try {
      this.router.urlFor(routeName);
      return true;
    } catch (e) {
      return false;
    }
  },
});
