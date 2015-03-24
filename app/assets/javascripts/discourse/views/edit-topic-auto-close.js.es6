import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/auto_close',
  title: I18n.t('topic.auto_close_title')
});
