import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminSiteSettingsController extends Controller {
  filter = "";

  @action
  filterChanged(filterData) {
    this.set("filter", filterData.filter);
  }
}
