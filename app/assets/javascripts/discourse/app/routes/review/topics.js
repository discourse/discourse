import DiscourseRoute from "discourse/routes/discourse";

export default class ReviewTopics extends DiscourseRoute {
  model() {
    return this.store.findAll("reviewable-topic");
  }

  setupController(controller, model) {
    controller.set("reviewableTopics", model);
  }
}
