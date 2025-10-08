import Controller from "@ember/controller";
import { action } from "@ember/object";
import computed from "discourse/lib/decorators";

export default class CakedayAnniversariesAllController extends Controller {
  queryParams = ["month"];
  month = moment().month() + 1;

  @computed
  months() {
    return moment.months().map((month, index) => {
      return { name: month, value: index + 1 };
    });
  }

  @action
  loadMore() {
    this.get("model").loadMore();
  }
}
