import Route from "@ember/routing/route";
import { service } from "discourse/lib/service";
import AdminPluginNavManagerService from "discourse/admin/services/admin-plugin-nav-manager";

export default class AdminPluginsShowIndexRoute extends Route {
  @service router;
  @service(() => AdminPluginNavManagerService) adminPluginNavManager;

  model() {
    return this.modelFor("adminPlugins.show");
  }

  afterModel(model) {
    if (this.adminPluginNavManager.currentPluginDefaultRoute) {
      this.router.replaceWith(
        this.adminPluginNavManager.currentPluginDefaultRoute,
        model.id
      );
    }
  }
}
