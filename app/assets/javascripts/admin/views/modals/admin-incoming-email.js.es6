import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'admin/templates/modal/admin_incoming_email',
  classNames: ['incoming-emails'],
  title: I18n.t('admin.email.incoming_emails.modal.title')
});
