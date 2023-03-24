import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class AdminDashboardReportsRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/reports");
  }

  setupController(controller, model) {
    controller.setProperties({ model: model.reports, filter: null });
  }
}
