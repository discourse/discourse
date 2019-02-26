import AdminEmailLogsController from "admin/controllers/admin-email-logs";
import debounce from "discourse/lib/debounce";

export default AdminEmailLogsController.extend({
  filterEmailLogs: debounce(function() {
    this.loadLogs();
  }, 250).observes("filter.{status,user,address,type}")
});
