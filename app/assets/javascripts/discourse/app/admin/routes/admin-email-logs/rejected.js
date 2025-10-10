import { i18n } from "discourse-i18n";
import AdminEmailLogsRoute from "admin/routes/admin-email-logs";

export default class AdminEmailLogsRejectedRoute extends AdminEmailLogsRoute {
  status = "rejected";

  titleToken() {
    return i18n("admin.config.email_logs.sub_pages.rejected.title");
  }
}
