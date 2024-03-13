import Route from "@ember/routing/route";
import { inject as service } from "@ember/service";
import SiteSetting from "admin/models/site-setting";

export default class AdminPluginsShowSettingsRoute extends Route {
  @service router;

  model() {
    const plugin = this.modelFor("adminPlugins.show");
    return SiteSetting.findAll({ plugin: plugin.name }).then((settings) => {
      return { plugin, settings };
    });
  }
}
