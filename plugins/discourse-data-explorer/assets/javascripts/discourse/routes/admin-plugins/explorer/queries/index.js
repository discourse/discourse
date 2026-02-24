import Route from "@ember/routing/route";
import { service } from "@ember/service";

const PLUGIN_ID = "discourse-data-explorer";

export default class AdminPluginsExplorerQueriesIndexRoute extends Route {
  @service router;

  beforeModel() {
    this.router.replaceWith("adminPlugins.show.explorer", PLUGIN_ID);
  }
}
