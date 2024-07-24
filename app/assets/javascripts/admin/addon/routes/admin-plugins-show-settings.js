import Route from "@ember/routing/route";
import { inject as service } from "@ember/service";
import SiteSetting from "admin/models/site-setting";

export default class AdminPluginsShowSettingsRoute extends Route {
  @service router;

  queryParams = {
    filter: { replace: true },
  };

  async model(params) {
    const plugin = this.modelFor("adminPlugins.show");
    const settings = await SiteSetting.findAll({ plugin: plugin.name });

    return { plugin, settings, initialFilter: params.filter };
  }
}
