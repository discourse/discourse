import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPermalinksEditRoute extends DiscourseRoute {
  @service store;

  model(params) {
    return this.store.find("permalink", params.permalink_id);
  }
}
