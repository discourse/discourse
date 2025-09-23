import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class AdminPluginsShowIndexRoute extends Route {
  @service router;
  @service adminPluginNavManager;

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
