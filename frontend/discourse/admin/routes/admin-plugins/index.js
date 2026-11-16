import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class AdminPluginsIndexRoute extends Route {
  @service adminPluginNavManager;

  queryParams = {
    filter: { replace: true },
  };

  afterModel() {
    this.adminPluginNavManager.viewingPluginsList = true;
  }

  deactivate() {
    this.adminPluginNavManager.viewingPluginsList = false;
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.set("filter", null);
    }
  }
}
