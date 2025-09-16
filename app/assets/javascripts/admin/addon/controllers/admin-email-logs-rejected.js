import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import AdminEmailLogsController from "admin/controllers/admin-email-logs";
import IncomingEmail from "admin/models/incoming-email";

export default class AdminEmailLogsRejectedController extends AdminEmailLogsController {
  @tracked filterFrom = "";
  @tracked filterTo = "";
  @tracked filterSubject = "";
  @tracked filterError = "";

  filters = [
    { property: "filterFrom", name: "from" },
    { property: "filterTo", name: "to" },
    { property: "filterSubject", name: "subject" },
    { property: "filterError", name: "error" },
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
      case "error":
        this.filterError = value;
        break;
    }

    discourseDebounce(this, this.loadLogs, IncomingEmail, INPUT_DELAY);
  }

  @action
  handleShowIncomingEmail(id, event) {
    event?.preventDefault();
    this.send("showIncomingEmail", id);
  }

  @action
  loadMore() {
    this.loadLogs(IncomingEmail, true);
  }
}
