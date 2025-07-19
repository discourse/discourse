import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { adminRouteValid } from "discourse/lib/admin-utilities";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import SiteSetting from "admin/models/site-setting";

export default class AdminPluginsIndexController extends Controller {
  @service session;
  @service adminPluginNavManager;
  @service router;

  get searchableProps() {
    return ["nameTitleized", "author", "about"];
  }

  get dropdownOptions() {
    return [
      { value: "all", label: i18n("admin.plugins.filters.all") },
      {
        value: "enabled",
        label: i18n("admin.plugins.filters.enabled"),
        filterFn: (item) => item.enabled,
      },
      {
        value: "disabled",
        label: i18n("admin.plugins.filters.disabled"),
        filterFn: (item) => !item.enabled,
      },
      {
        value: "preinstalled",
        label: i18n("admin.plugins.filters.preinstalled"),
        filterFn: (item) =>
          item.url?.includes("/discourse/discourse/tree/main/plugins/"),
      },
    ];
  }

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

  // NOTE: See also AdminPluginsController, there is some duplication here
  // while we convert plugins to use_new_show_route
  get adminRoutes() {
    return this.allAdminRoutes.filter((route) =>
      adminRouteValid(this.router, route)
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
}
