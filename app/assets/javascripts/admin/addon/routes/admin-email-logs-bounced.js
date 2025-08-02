import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import IncomingEmail from "admin/models/incoming-email";
import AdminEmailLogs from "admin/routes/admin-email-logs";
import IncomingEmailModal from "../components/modal/incoming-email";

export default class AdminEmailLogsBouncedRoute extends AdminEmailLogs {
  @service modal;

  status = "bounced";

  titleToken() {
    return i18n("admin.config.email_logs.sub_pages.bounced.title");
  }

  @action
  async showIncomingEmail(id) {
    const model = await this.loadFromBounced(id);
    this.modal.show(IncomingEmailModal, { model });
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
