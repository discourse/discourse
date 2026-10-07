import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsExplorerNew extends DiscourseRoute {
  async model() {
    const [schema, groups, availableTags] = await Promise.all([
      ajax("/admin/plugins/discourse-data-explorer/schema.json", {
        cache: true,
      }),
      ajax("/admin/plugins/discourse-data-explorer/groups.json"),
      ajax("/admin/plugins/discourse-data-explorer/queries/tags.json"),
    ]);

    return { schema, groups, availableTags };
  }

  setupController(controller, model) {
    controller.resetState();
    controller.setProperties({
      schema: model.schema,
      groups: model.groups,
      availableTags: model.availableTags,
    });
  }

  resetController(controller) {
    controller.resetState();
  }
}
