import { action } from "@ember/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import IncomingEmail from "admin/models/incoming-email";
import AdminEmailLogsRoute from "admin/routes/admin-email-logs";

export default class AdminEmailLogsBouncedRoute extends AdminEmailLogsRoute {
  status = "bounced";

  titleToken() {
    return i18n("admin.config.email_logs.sub_pages.bounced.title");
  }

  @action
  async loadFromBounced(id) {
    try {
      return await IncomingEmail.findByBounced(id);
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
