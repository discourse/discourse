import { action } from "@ember/object";
import AdminEmailIncomings from "admin/routes/admin-email-incomings";
import showModal from "discourse/lib/show-modal";

export default class AdminEmailRejectedRoute extends AdminEmailIncomings {
  status = "rejected";

  @action
  showIncomingEmail(id) {
    showModal("admin-incoming-email", { admin: true });
    this.controllerFor("modals/admin-incoming-email").load(id);
  }
}
