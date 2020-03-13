import AdminEmailLogsController from "admin/controllers/admin-email-logs";
import discourseDebounce from "discourse/lib/debounce";
import { observes } from "discourse-common/utils/decorators";
import { INPUT_DELAY } from "discourse-common/config/environment";

export default AdminEmailLogsController.extend({
  @observes("filter.{status,user,address,type}")
  filterEmailLogs: discourseDebounce(function() {
    this.loadLogs();
  }, INPUT_DELAY)
});
