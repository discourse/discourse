import showModal from 'discourse/lib/show-modal';
import AdminEmailIncomings from 'admin/routes/admin-email-incomings';

export default AdminEmailIncomings.extend({
  status: "rejected",

  actions: {
    showIncomingEmail(id) {
      showModal('modals/admin-incoming-email');
      this.controllerFor("modals/admin-incoming-email").load(id);
    }
  }

});
