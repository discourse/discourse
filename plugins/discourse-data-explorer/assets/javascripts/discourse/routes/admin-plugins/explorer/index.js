import Route from "@ember/routing/route";
import { service } from "@ember/service";

const PLUGIN_ID = "discourse-data-explorer";

export default class AdminPluginsExplorerIndexRoute extends Route {
  @service router;

  beforeModel(transition) {
    const { id, ...queryParams } = transition.to.queryParams;
    if (id) {
      this.router.transitionTo(
        "adminPlugins.show.explorer.queries.details",
        PLUGIN_ID,
        id,
        { queryParams }
      );
      return;
    }

    this.router.transitionTo("adminPlugins.show.explorer", PLUGIN_ID, {
      queryParams,
    });
  }
}
