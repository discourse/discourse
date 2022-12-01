import DiscourseRoute from "discourse/routes/discourse";

export default class extends DiscourseRoute {
  model() {
    return this.modelFor("user");
  }

  setupController(controller, model) {
    controller.set("model", model);
  }
}
