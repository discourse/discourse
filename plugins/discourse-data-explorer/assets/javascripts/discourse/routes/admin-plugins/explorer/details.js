import Route from "@ember/routing/route";
import { service } from "@ember/service";

const PLUGIN_ID = "discourse-data-explorer";

export default class AdminPluginsExplorerQueriesDetailsRoute extends Route {
  @service router;

  beforeModel(transition) {
    this.router.transitionTo(
      "adminPlugins.show.explorer.details",
      PLUGIN_ID,
      transition.to.params.query_id,
      { queryParams: transition.to.queryParams }
    );
  }
}
