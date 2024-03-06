import Route from "@ember/routing/route";
import { service } from "@ember/service";
import AdminPlugin from "admin/models/admin-plugin";

export default class AdminPluginsRoute extends Route {
  @service router;

  model() {
    return this.store
      .findAll("plugin")
      .then((plugins) => plugins.map((plugin) => AdminPlugin.create(plugin)));
  }
}
