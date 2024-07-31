import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminBackupsSettingsController extends Controller {
  filter = "";

  @action
  filterChanged(filterData) {
    this.set("filter", filterData.filter);
  }
}
