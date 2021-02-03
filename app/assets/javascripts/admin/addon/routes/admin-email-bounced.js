import AdminEmailLogs from "admin/routes/admin-email-logs";
import showModal from "discourse/lib/show-modal";

export default AdminEmailLogs.extend({
  status: "bounced",

  actions: {
    showIncomingEmail(id) {
      showModal("admin-incoming-email", { admin: true });
      this.controllerFor("modals/admin-incoming-email").loadFromBounced(id);
    },
  },
});
