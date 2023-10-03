import { action } from "@ember/object";
import AdminEmailLogs from "admin/routes/admin-email-logs";
import IncomingEmail from "admin/models/incoming-email";
import IncomingEmailModal from "../components/modal/incoming-email";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";

export default class AdminEmailBouncedRoute extends AdminEmailLogs {
  @service modal;
  status = "bounced";

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
