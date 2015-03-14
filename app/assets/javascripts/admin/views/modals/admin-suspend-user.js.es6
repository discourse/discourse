import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'admin/templates/modal/admin_suspend_user',
  title: I18n.t('admin.user.suspend_modal_title')
});
