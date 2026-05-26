import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsExplorerNew extends DiscourseRoute {
  model() {
    return ajax("/admin/plugins/discourse-data-explorer/schema.json", {
      cache: true,
    }).then((schema) => ({ schema }));
  }

  setupController(controller, model) {
    controller.setProperties({ schema: model.schema });
  }

  resetController(controller) {
    controller.resetState();
  }
}
