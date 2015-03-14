import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'admin/templates/modal/admin_agree_flag',
  title: I18n.t('admin.flags.agree_flag_modal_title')
});
