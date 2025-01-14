import { observes } from "@ember-decorators/object";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import AdminEmailLogsController from "admin/controllers/admin-email-logs";

export default class AdminEmailSentController extends AdminEmailLogsController {
  ccAddressDisplayThreshold = 2;
  sortWithAddressFilter = (addresses) => {
    if (!Array.isArray(addresses) || addresses.length === 0) {
      return [];
    }
    const targetEmail = this.filter.address;

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

  @observes("filter.{status,user,address,type,reply_key}")
  filterEmailLogs() {
    discourseDebounce(this, this.loadLogs, INPUT_DELAY);
  }
}
