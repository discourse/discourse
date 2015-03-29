import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/invite_private',
  title: I18n.t('topic.invite_private.title')
});
