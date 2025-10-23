import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ReviewShow extends DiscourseRoute {
  @service store;

  model({ reviewable_id }) {
    return this.store.find("reviewable", reviewable_id);
  }

  setupController(controller, model) {
    controller.set("reviewable", model);
  }
}
