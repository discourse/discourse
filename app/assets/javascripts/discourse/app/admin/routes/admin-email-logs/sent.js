import { i18n } from "discourse-i18n";
import AdminEmailLogsRoute from "admin/routes/admin-email-logs";

export default class AdminEmailLogsSentRoute extends AdminEmailLogsRoute {
  status = "sent";

  titleToken() {
    return i18n("admin.config.email_logs.sub_pages.sent.title");
  }
}
