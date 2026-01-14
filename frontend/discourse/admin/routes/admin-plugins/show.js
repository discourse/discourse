import { service } from "@ember/service";
import AdminPlugin from "discourse/admin/models/admin-plugin";
import { ajax } from "discourse/lib/ajax";
import { sanitize } from "discourse/lib/text";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsShowRoute extends DiscourseRoute {
  @service adminPluginNavManager;

  async model(params) {
    const pluginId = sanitize(params.plugin_id).substring(0, 100);
    const pluginAttrs = await ajax(`/admin/plugins/${pluginId}.json`);
    return AdminPlugin.create(pluginAttrs);
  }

  afterModel(model) {
    this.adminPluginNavManager.currentPlugin = model;
  }

  deactivate() {
    this.adminPluginNavManager.currentPlugin = null;
  }

  titleToken() {
    return this.adminPluginNavManager.currentPlugin.nameTitleized;
  }
}
