import Route from "@ember/routing/route";
import { service } from "@ember/service";
import AdminPlugin from "admin/models/admin-plugin";

export default class AdminPluginsRoute extends Route {
  @service router;

  async model() {
    const plugins = await this.store.findAll("plugin");
    return plugins.map((plugin) => AdminPlugin.create(plugin));
  }
}
