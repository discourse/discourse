import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'admin/templates/logs/details_modal',
  title: I18n.t('admin.logs.staff_actions.modal_title')
});
