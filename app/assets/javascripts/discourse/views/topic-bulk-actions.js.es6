import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/topic-bulk-actions',
  title: I18n.t('topics.bulk.actions')
});
