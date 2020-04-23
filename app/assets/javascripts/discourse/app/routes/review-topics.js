import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model() {
    return this.store.findAll("reviewable-topic");
  },

  setupController(controller, model) {
    controller.set("reviewableTopics", model);
  }
});
