import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";
import StoreService from "discourse/services/store";

export default class ReviewShow extends DiscourseRoute {
  @service(() => StoreService) store;

  model({ reviewable_id }) {
    return this.store.find("reviewable", reviewable_id);
  }

  setupController(controller, model) {
    controller.set("reviewable", model);
  }
}
