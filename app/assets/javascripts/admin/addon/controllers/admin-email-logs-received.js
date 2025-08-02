import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import AdminEmailLogsController from "admin/controllers/admin-email-logs";
import IncomingEmail from "admin/models/incoming-email";

export default class AdminEmailLogsReceivedController extends AdminEmailLogsController {
  @tracked filterFrom = "";
  @tracked filterTo = "";
  @tracked filterSubject = "";

  filters = [
    { property: "filterFrom", name: "from" },
    { property: "filterTo", name: "to" },
    { property: "filterSubject", name: "subject" },
  ];

  @action
  updateFilter(filterType, event) {
    const value = event.target.value;

    switch (filterType) {
      case "from":
        this.filterFrom = value;
        break;
      case "to":
        this.filterTo = value;
        break;
      case "subject":
        this.filterSubject = value;
        break;
    }

    discourseDebounce(this, this.loadLogs, IncomingEmail, INPUT_DELAY);
  }

  @action
  loadMore() {
    this.loadLogs(IncomingEmail, true);
  }
}
