import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminAreaSettingsBaseController extends Controller {
  filter = "";
  queryParams = [
    {
      filter: { replace: true },
    },
  ];

  @action
  adminSettingsFilterChangedCallback(filter) {
    if (this.filter === filter) {
      return;
    }
    this.set("filter", filter);
  }
}
