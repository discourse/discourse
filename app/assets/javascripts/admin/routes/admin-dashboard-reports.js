import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default DiscourseRoute.extend({
  model() {
    return ajax("/admin/reports");
  },

  setupController(controller, model) {
    controller.setProperties({ model: model.reports, filter: null });
  }
});
