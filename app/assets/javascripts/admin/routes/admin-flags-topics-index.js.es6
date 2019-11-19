import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model() {
    return this.store.findAll("flagged-topic");
  },

  setupController(controller, model) {
    controller.set("flaggedTopics", model);
  }
});
