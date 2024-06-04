import DiscourseRoute from "discourse/routes/discourse";

export default class ReviewShow extends DiscourseRoute {
  setupController(controller, model) {
    controller.set("reviewable", model);
  }
}
