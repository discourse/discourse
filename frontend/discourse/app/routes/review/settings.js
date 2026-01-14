import DiscourseRoute from "discourse/routes/discourse";

export default class ReviewSettings extends DiscourseRoute {
  model() {
    return this.store.find("reviewable-settings");
  }

  setupController(controller, model) {
    controller.set("settings", model);
  }
}
