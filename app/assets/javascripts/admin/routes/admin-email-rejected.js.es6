import showModal from 'discourse/lib/show-modal';
import AdminEmailIncomings from 'admin/routes/admin-email-incomings';

export default AdminEmailIncomings.extend({
  status: "rejected",

  actions: {
    showRawEmail(incomingEmailId) {
      showModal('raw-email');
      this.controllerFor('raw_email').loadIncomingRawEmail(incomingEmailId);
    }
  }

});
