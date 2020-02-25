import AdminEmailLogsController from "admin/controllers/admin-email-logs";
import discourseDebounce from "discourse/lib/debounce";
import IncomingEmail from "admin/models/incoming-email";
import { observes } from "discourse-common/utils/decorators";

export default AdminEmailLogsController.extend({
  @observes("filter.{status,from,to,subject,error}")
  filterIncomingEmails: discourseDebounce(function() {
    this.loadLogs(IncomingEmail);
  }, 250),

  actions: {
    loadMore() {
      this.loadLogs(IncomingEmail, true);
    }
  }
});
