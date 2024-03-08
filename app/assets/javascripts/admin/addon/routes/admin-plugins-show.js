import Route from "@ember/routing/route";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import AdminPlugin from "admin/models/admin-plugin";

export default class AdminPluginsShowRoute extends Route {
  @service router;

  model(params) {
    return ajax("/admin/plugins/" + params.plugin_id + ".json").then(
      (plugin) => {
        return AdminPlugin.create(plugin);
      }
    );
  }
}
