import { i18n } from "discourse-i18n";
import AdminEmailIncomings from "admin/routes/admin-email-incomings";

export default class AdminEmailLogsReceivedRoute extends AdminEmailIncomings {
  status = "received";

  titleToken() {
    return i18n("admin.config.email_logs.sub_pages.received.title");
  }
}
