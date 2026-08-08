import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SiteSetting from "discourse/admin/models/site-setting";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminPluginsIndexController extends Controller {
  @service session;

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
}
