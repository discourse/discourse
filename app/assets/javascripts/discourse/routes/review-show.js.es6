import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  setupController(controller, model) {
    controller.set("reviewable", model);
  }
});
