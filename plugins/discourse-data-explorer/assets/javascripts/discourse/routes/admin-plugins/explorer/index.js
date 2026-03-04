import Route from "@ember/routing/route";
import { service } from "@ember/service";

const PLUGIN_ID = "discourse-data-explorer";

export default class AdminPluginsExplorerIndexRoute extends Route {
  @service router;

  beforeModel() {
    this.router.replaceWith("adminPlugins.show.explorer", PLUGIN_ID);
  }
}
