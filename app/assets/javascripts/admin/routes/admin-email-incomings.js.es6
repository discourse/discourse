import IncomingEmail from "admin/models/incoming-email";

export default Discourse.Route.extend({
  model() {
    return IncomingEmail.findAll({ status: this.get("status") });
  },

  setupController(controller, model) {
    controller.set("model", model);
    controller.set("filter", { status: this.get("status") });
  }
});
