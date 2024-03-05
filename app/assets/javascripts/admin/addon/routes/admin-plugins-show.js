import Route from "@ember/routing/route";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import AdminPlugin from "admin/models/admin-plugin";

export default class AdminPluginsShowRoute extends Route {
  @service router;
  @service currentUser;

  beforeModel() {
    if (!this.currentUser.use_admin_experimental_plugin_page) {
      return this.router.transitionTo("adminPlugins");
    }
  }

  model(params) {
    return ajax("/admin/plugins/" + params.plugin_id + ".json").then(
      (plugin) => {
        return AdminPlugin.create(plugin);
      }
    );
  }
}
