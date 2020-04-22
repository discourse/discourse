import DiscourseRoute from "discourse/routes/discourse";
import Permalink from "admin/models/permalink";

export default DiscourseRoute.extend({
  model() {
    return Permalink.findAll();
  },

  setupController(controller, model) {
    controller.set("model", model);
  }
});
