import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminDashboardReportsRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/reports");
  }

  setupController(controller, model) {
    controller.setProperties({ model: model.reports, filter: null });
  }
}
