import Controller from "@ember/controller";
import { action, set } from "@ember/object";
import { inject as service } from "@ember/service";
import SiteSetting from "admin/models/site-setting";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsIndexController extends Controller {
  @service session;

  @action
  async togglePluginEnabled(plugin) {
    const enabledSettingName = plugin.enabled_setting;

    const oldValue = plugin.enabled;
    const newValue = !oldValue;
    try {
      set(plugin, "enabled", newValue);
      await SiteSetting.update(enabledSettingName, newValue);
      this.session.requiresRefresh = true;
    } catch (e) {
      set(plugin, "enabled", oldValue);
      popupAjaxError(e);
    }
  }
}
