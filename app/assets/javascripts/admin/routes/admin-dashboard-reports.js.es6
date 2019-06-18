import { ajax } from "discourse/lib/ajax";

export default Discourse.Route.extend({
  model() {
    return ajax("/admin/reports").then(json => json);
  },

  setupController(controller, model) {
    controller.setProperties({ model: model.reports, filter: null });
  }
});
