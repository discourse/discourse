import Controller from "@ember/controller";
import { action, computed } from "@ember/object";

export default class CakedayAnniversariesAllController extends Controller {
  queryParams = ["month"];
  month = moment().month() + 1;

  @computed
  get months() {
    return moment.months().map((month, index) => {
      return { name: month, value: index + 1 };
    });
  }

  @action
  loadMore() {
    this.get("model").loadMore();
  }
}
