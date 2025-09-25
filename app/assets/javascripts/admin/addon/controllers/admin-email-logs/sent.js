import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import AdminEmailLogsController from "admin/controllers/admin-email-logs";

export default class AdminEmailLogsSentController extends AdminEmailLogsController {
  @tracked filterUser = "";
  @tracked filterAddress = "";
  @tracked filterType = "";
  @tracked filterReplyKey = "";

  sortWithAddressFilter = (addresses) => {
    if (!Array.isArray(addresses) || addresses.length === 0) {
      return [];
    }
    const targetEmail = this.filterAddress;

    if (!targetEmail) {
      return addresses;
    }

    return addresses.sort((a, b) => {
      if (a.includes(targetEmail) && !b.includes(targetEmail)) {
        return -1;
      }
      if (!a.includes(targetEmail) && b.includes(targetEmail)) {
        return 1;
      }
      return 0;
    });
  };

  filters = [
    { property: "filterUser", name: "user" },
    { property: "filterAddress", name: "address" },
    { property: "filterType", name: "type" },
    { property: "filterReplyKey", name: "reply_key" },
  ];

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
      case "reply_key":
        this.filterReplyKey = value;
        break;
    }

    discourseDebounce(this, this.loadLogs, INPUT_DELAY);
  }
}
