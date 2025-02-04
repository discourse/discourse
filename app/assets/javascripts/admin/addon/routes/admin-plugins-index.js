import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class AdminPluginsIndexRoute extends Route {
  @service adminPluginNavManager;

  afterModel() {
    this.adminPluginNavManager.viewingPluginsList = true;
  }

  deactivate() {
    this.adminPluginNavManager.viewingPluginsList = false;
  }
}
