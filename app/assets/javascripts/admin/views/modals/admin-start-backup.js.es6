import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'admin/templates/modal/admin_start_backup',
  title: I18n.t('admin.backups.operations.backup.confirm')
});
