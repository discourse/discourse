import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsExplorerIndex extends DiscourseRoute {
  @service router;
  @service dataExplorerMode;

  beforeModel(transition) {
    // Redirect old `?id=123` URLs to query details.
    const { id, ...queryParams } = transition.to.queryParams;
    if (id) {
      this.router.transitionTo("adminPlugins.show.explorer.edit", id, {
        queryParams,
      });
    }
  }

  async model() {
    if (!this.currentUser.admin) {
      // display "Only available to admins" message
      return { model: null, schema: null, disallow: true, groups: null };
    }

    const model = await this.store.findAll("query");

    let groups;
    if (this.dataExplorerMode.isFull) {
      groups = await ajax("/admin/plugins/discourse-data-explorer/groups.json");
      const groupNames = {};
      groups.forEach((g) => {
        groupNames[g.id] = g.name;
      });
      model.content.forEach((query) => {
        query.set(
          "group_names",
          (query.group_ids || []).map((id) => groupNames[id])
        );
      });
    }

    return { model, groups };
  }

  setupController(controller, model) {
    controller.setProperties(model);
  }
}
