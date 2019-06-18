import AdminEmailLogsController from "admin/controllers/admin-email-logs";
import debounce from "discourse/lib/debounce";
import IncomingEmail from "admin/models/incoming-email";

export default AdminEmailLogsController.extend({
  filterIncomingEmails: debounce(function() {
    this.loadLogs(IncomingEmail);
  }, 250).observes("filter.{status,from,to,subject,error}"),

  actions: {
    loadMore() {
      this.loadLogs(IncomingEmail, true);
    }
  }
});
