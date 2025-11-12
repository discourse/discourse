import AdminEmailLogsRoute from "discourse/admin/routes/admin-email-logs";
import { i18n } from "discourse-i18n";

export default class AdminEmailLogsRejectedRoute extends AdminEmailLogsRoute {
  titleToken() {
    return i18n("admin.config.email_logs.sub_pages.rejected.title");
  }
}
