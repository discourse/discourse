import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminEmojisSettingsController extends Controller {
  filter = "";
  queryParams = ["filter"];

  @action
  filterChangedCallback(filterData) {
    this.set("filter", filterData.filter);
  }
}
