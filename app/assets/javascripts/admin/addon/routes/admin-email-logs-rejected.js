import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import IncomingEmail from "admin/models/incoming-email";
import AdminEmailIncomings from "admin/routes/admin-email-incomings";
import IncomingEmailModal from "../components/modal/incoming-email";

export default class AdminEmailLogsRejectedRoute extends AdminEmailIncomings {
  @service modal;

  status = "rejected";

  titleToken() {
    return i18n("admin.config.email_logs.sub_pages.rejected.title");
  }

  @action
  async showIncomingEmail(id) {
    const model = await IncomingEmail.find(id);
    this.modal.show(IncomingEmailModal, { model });
  }
}
