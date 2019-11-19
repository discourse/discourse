import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model() {
    return this.store.find("reviewable-settings");
  },

  setupController(controller, model) {
    controller.set("settings", model);
  }
});
