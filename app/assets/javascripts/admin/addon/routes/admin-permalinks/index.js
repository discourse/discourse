import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPermalinksIndexRoute extends DiscourseRoute {
  setupController(controller, model) {
    super.setupController(...arguments);
    controller.set("hasPermalinks", model.length > 0);
  }
}
