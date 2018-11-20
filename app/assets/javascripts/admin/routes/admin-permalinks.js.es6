import Permalink from "admin/models/permalink";

export default Discourse.Route.extend({
  model() {
    return Permalink.findAll();
  },

  setupController(controller, model) {
    controller.set("model", model);
  }
});
