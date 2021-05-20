import AdminEmailIncomings from "admin/routes/admin-email-incomings";
import showModal from "discourse/lib/show-modal";

export default AdminEmailIncomings.extend({
  status: "rejected",

  actions: {
    showIncomingEmail(id) {
      showModal("admin-incoming-email", { admin: true });
      this.controllerFor("modals/admin-incoming-email").load(id);
    },
  },
});
