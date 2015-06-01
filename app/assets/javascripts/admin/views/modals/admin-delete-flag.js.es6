import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'admin/templates/modal/admin_delete_flag',
  title: I18n.t('admin.flags.delete_flag_modal_title')
});
