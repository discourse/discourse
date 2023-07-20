import DiscourseRoute from "discourse/routes/discourse";

export default class AdminFlagsTopicsIndexRoute extends DiscourseRoute {
  model() {
    return this.store.findAll("flagged-topic");
  }

  setupController(controller, model) {
    controller.set("flaggedTopics", model);
  }
}
