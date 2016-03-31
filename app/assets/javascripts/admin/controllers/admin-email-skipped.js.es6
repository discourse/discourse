import AdminEmailLogsController from 'admin/controllers/admin-email-logs';
import debounce from 'discourse/lib/debounce';
import EmailLog from 'admin/models/email-log';

export default AdminEmailLogsController.extend({
  filterEmailLogs: debounce(function() {
    EmailLog.findAll(this.get("filter")).then(logs => this.set("model", logs));
  }, 250).observes("filter.{user,address,type,skipped_reason}")
});
