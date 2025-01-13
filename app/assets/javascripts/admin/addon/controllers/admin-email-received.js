import { action } from "@ember/object";
import { observes } from "@ember-decorators/object";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse-common/config/environment";
import AdminEmailLogsController from "admin/controllers/admin-email-logs";
import IncomingEmail from "admin/models/incoming-email";

export default class AdminEmailReceivedController extends AdminEmailLogsController {
  @observes("filter.{status,from,to,subject}")
  filterIncomingEmails() {
    discourseDebounce(this, this.loadLogs, IncomingEmail, INPUT_DELAY);
  }

  @action
  loadMore() {
    this.loadLogs(IncomingEmail, true);
  }
}
