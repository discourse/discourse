import AdminEmailLogsController from "admin/controllers/admin-email-logs";
import discourseDebounce from "discourse/lib/debounce";

export default AdminEmailLogsController.extend({
  filterEmailLogs: discourseDebounce(function() {
    this.loadLogs();
  }, 250).observes("filter.{status,user,address,type}")
});
