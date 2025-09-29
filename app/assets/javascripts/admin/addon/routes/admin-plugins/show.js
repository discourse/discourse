import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { sanitize } from "discourse/lib/text";
import DiscourseRoute from "discourse/routes/discourse";
import AdminPlugin from "admin/models/admin-plugin";

export default class AdminPluginsShowRoute extends DiscourseRoute {
  @service router;
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
