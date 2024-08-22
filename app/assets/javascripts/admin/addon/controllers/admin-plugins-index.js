import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import SiteSetting from "admin/models/site-setting";

export default class AdminPluginsIndexController extends Controller {
  @service session;
  @service adminPluginNavManager;
  @service router;

  @action
  async togglePluginEnabled(plugin) {
    const oldValue = plugin.enabled;
    const newValue = !oldValue;

    try {
      plugin.enabled = newValue;
      await SiteSetting.update(plugin.enabledSetting, newValue);
      this.session.requiresRefresh = true;
    } catch (e) {
      plugin.enabled = oldValue;
      popupAjaxError(e);
    }
  }

  get adminRoutes() {
    return this.allAdminRoutes.filter((route) => this.routeExists(route));
  }

  get allAdminRoutes() {
    return this.model
      .filter((plugin) => plugin?.enabled)
      .map((plugin) => {
        return plugin.adminRoute;
      })
      .filter(Boolean);
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
