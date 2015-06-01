import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/search_help',
  title: I18n.t('search_help.title'),
  focusInput: false
});
