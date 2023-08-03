import Controller from "@ember/controller";
import { action, set } from "@ember/object";
import { inject as service } from "@ember/service";
import SiteSetting from "admin/models/site-setting";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { TrackedMap } from "@ember-compat/tracked-built-ins";

export default class AdminPluginsIndexController extends Controller {
  @service session;
  loading = new TrackedMap();

  @action
  async togglePluginEnabled(plugin) {
    const enabledSettingName = plugin.enabled_setting;
    const enabled = plugin.enabled;
    this.loading.set(plugin, true);

    try {
      await SiteSetting.update(enabledSettingName, !enabled);
      set(plugin, "enabled", !enabled);
      this.session.requiresRefresh = true;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading.delete(plugin);
    }
  }

  @action
  isLoading(plugin) {
    return !!this.loading.get(plugin);
  }
}
