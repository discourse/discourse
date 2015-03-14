import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'admin/templates/logs/site_customization_change_modal',
  title: I18n.t('admin.logs.staff_actions.modal_title')
});
