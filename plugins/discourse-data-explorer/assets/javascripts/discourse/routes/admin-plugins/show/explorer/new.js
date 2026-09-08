import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsExplorerNew extends DiscourseRoute {
  async model() {
    const [schema, groups] = await Promise.all([
      ajax("/admin/plugins/discourse-data-explorer/schema.json", {
        cache: true,
      }),
      ajax("/admin/plugins/discourse-data-explorer/groups.json"),
    ]);

    return { schema, groups };
  }

  setupController(controller, model) {
    controller.resetState();
    controller.setProperties({ schema: model.schema, groups: model.groups });
  }

  resetController(controller) {
    controller.resetState();
  }
}
