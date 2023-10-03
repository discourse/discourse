import Route from "@ember/routing/route";
import AdminPlugin from "admin/models/admin-plugin";
import { inject as service } from "@ember/service";

export default class AdminPluginsRoute extends Route {
  @service router;

  model() {
    return this.store
      .findAll("plugin")
      .then((plugins) => plugins.map((plugin) => AdminPlugin.create(plugin)));
  }
}
