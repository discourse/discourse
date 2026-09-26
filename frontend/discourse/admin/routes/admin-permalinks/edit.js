import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";
import StoreService from "discourse/services/store";

export default class AdminPermalinksEditRoute extends DiscourseRoute {
  @service(() => StoreService) store;

  model(params) {
    return this.store.find("permalink", params.permalink_id);
  }
}
