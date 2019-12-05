import AdminEmailLogsController from "admin/controllers/admin-email-logs";
import discourseDebounce from "discourse/lib/debounce";
import IncomingEmail from "admin/models/incoming-email";

export default AdminEmailLogsController.extend({
  filterIncomingEmails: discourseDebounce(function() {
    this.loadLogs(IncomingEmail);
  }, 250).observes("filter.{status,from,to,subject,error}"),

  actions: {
    loadMore() {
      this.loadLogs(IncomingEmail, true);
    }
  }
});
