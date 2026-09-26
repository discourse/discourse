import Route from "@ember/routing/route";
import { service } from "discourse/lib/service";
import AdminPluginNavManagerService from "discourse/admin/services/admin-plugin-nav-manager";

export default class AdminPluginsIndexRoute extends Route {
  @service(() => AdminPluginNavManagerService) adminPluginNavManager;

  afterModel() {
    this.adminPluginNavManager.viewingPluginsList = true;
  }

  deactivate() {
    this.adminPluginNavManager.viewingPluginsList = false;
  }
}
