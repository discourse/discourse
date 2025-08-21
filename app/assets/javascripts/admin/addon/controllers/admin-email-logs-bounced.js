import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import AdminEmailLogsController from "admin/controllers/admin-email-logs";

export default class AdminEmailLogsBouncedController extends AdminEmailLogsController {
  @tracked filterUser = "";
  @tracked filterAddress = "";
  @tracked filterType = "";

  filters = [
    { property: "filterUser", name: "user" },
    { property: "filterAddress", name: "address" },
    { property: "filterType", name: "type" },
  ];

  @action
  handleShowIncomingEmail(id, event) {
    event?.preventDefault();
    this.send("showIncomingEmail", id);
  }

  @action
  updateFilter(filterType, event) {
    const value = event.target.value;

    switch (filterType) {
      case "user":
        this.filterUser = value;
        break;
      case "address":
        this.filterAddress = value;
        break;
      case "type":
        this.filterType = value;
        break;
    }

    discourseDebounce(this, this.loadLogs, INPUT_DELAY);
  }
}
