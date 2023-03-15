import { action } from "@ember/object";
import AdminEmailLogs from "admin/routes/admin-email-logs";
import showModal from "discourse/lib/show-modal";

export default class AdminEmailBouncedRoute extends AdminEmailLogs {
  status = "bounced";

  @action
  showIncomingEmail(id) {
    showModal("admin-incoming-email", { admin: true });
    this.controllerFor("modals/admin-incoming-email").loadFromBounced(id);
  }
}
