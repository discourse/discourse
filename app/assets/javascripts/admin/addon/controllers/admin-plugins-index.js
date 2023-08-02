import Controller from "@ember/controller";
import { action, set } from "@ember/object";
import { inject as service } from "@ember/service";
import SiteSetting from "admin/models/site-setting";
import { tracked } from "@glimmer/tracking";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminPluginsIndexController extends Controller {
  @service session;
  @tracked isLoading = false;

  @action
  async togglePluginEnabled(plugin) {
    const enabledSettingName = plugin.enabled_setting;
    const enabled = plugin.enabled;
    this.isLoading = true;

    try {
      await SiteSetting.update(enabledSettingName, !enabled);
      set(plugin, "enabled", !enabled);
      this.isLoading = false;
      this.session.requiresRefresh = true;
    } catch (e) {
      popupAjaxError(e);
    }
  }
}
