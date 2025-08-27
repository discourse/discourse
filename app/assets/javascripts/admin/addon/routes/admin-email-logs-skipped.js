import { i18n } from "discourse-i18n";
import AdminEmailLogs from "admin/routes/admin-email-logs";

export default class AdminEmailLogsSkippedRoute extends AdminEmailLogs {
  status = "skipped";

  titleToken() {
    return i18n("admin.config.email_logs.sub_pages.skipped.title");
  }
}
