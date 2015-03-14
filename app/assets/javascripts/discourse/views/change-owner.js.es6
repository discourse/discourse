import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/change_owner',
  title: I18n.t('topic.change_owner.title')
});
