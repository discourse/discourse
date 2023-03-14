import AdminEmailLogsController from "admin/controllers/admin-email-logs";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import { observes } from "@ember-decorators/object";

export default class AdminEmailSkippedController extends AdminEmailLogsController {
  @observes("filter.{status,user,address,type}")
  filterEmailLogs() {
    discourseDebounce(this, this.loadLogs, INPUT_DELAY);
  }
}
