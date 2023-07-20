import DiscourseRoute from "discourse/routes/discourse";
import IncomingEmail from "admin/models/incoming-email";

export default class AdminEmailIncomingsRoute extends DiscourseRoute {
  model() {
    return IncomingEmail.findAll({ status: this.status });
  }

  setupController(controller, model) {
    controller.set("model", model);
    controller.set("filter.status", this.status);
  }
}
