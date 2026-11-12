import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { findQueries } from "discourse/plugins/discourse-data-explorer/discourse/data/builders/queries";

export default class AdminPluginsExplorerIndex extends DiscourseRoute {
  @service router;
  @service warpStore;

  beforeModel(transition) {
    // Redirect old `?id=123` URLs to query details.
    const { id, ...queryParams } = transition.to.queryParams;
    if (id) {
      this.router.transitionTo("adminPlugins.show.explorer.edit", id, {
        queryParams,
      });
    }
  }

  async model(_params, transition) {
    const controller = this.controllerFor("adminPlugins.show.explorer.index");
    const [{ content }, queryTags] = await Promise.all([
      this.warpStore.request(
        findQueries({
          ...controller.fetchParams,
          tags: transition.to.queryParams.tags?.split(","),
        })
      ),
      ajax("/admin/plugins/discourse-data-explorer/queries/tags.json"),
    ]);

    return { document: content, queryTags };
  }

  setupController(controller, { document, queryTags }) {
    controller.reset(document, queryTags);
  }
}
