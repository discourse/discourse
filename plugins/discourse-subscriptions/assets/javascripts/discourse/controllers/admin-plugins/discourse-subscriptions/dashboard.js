import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminPluginsDiscourseSubscriptionsDashboardController extends Controller {
  queryParams = ["order", "descending"];
  order = null;
  descending = true;

  @action
  loadMore() {}

  @action
  orderPayments(order) {
    if (order === this.get("order")) {
      this.toggleProperty("descending");
    }

    this.set("order", order);
  }
}
