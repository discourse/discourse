import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'admin/templates/modal/admin_badge_preview',
  title: I18n.t('admin.badges.preview.modal_title')
});
