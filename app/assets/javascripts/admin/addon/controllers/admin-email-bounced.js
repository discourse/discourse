import { action } from "@ember/object";
import { observes } from "@ember-decorators/object";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import AdminEmailLogsController from "admin/controllers/admin-email-logs";

export default class AdminEmailBouncedController extends AdminEmailLogsController {
  @action
  handleShowIncomingEmail(id, event) {
    event?.preventDefault();
    this.send("showIncomingEmail", id);
  }

  @observes("filter.{status,user,address,type}")
  filterEmailLogs() {
    discourseDebounce(this, this.loadLogs, INPUT_DELAY);
  }
}
