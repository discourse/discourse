import Controller from "@ember/controller";
import { action, set } from "@ember/object";
import { inject as service } from "@ember/service";
import SiteSetting from "admin/models/site-setting";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsIndexController extends Controller {
  @service store;

  @action
  async togglePluginEnabled(plugin) {
    const enabledSettingName = plugin.enabled_setting;
    const enabled = plugin.enabled;

    try {
      await SiteSetting.update(enabledSettingName, !enabled);
      set(plugin, "enabled", !enabled);
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
