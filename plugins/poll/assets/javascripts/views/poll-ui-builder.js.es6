import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modals/poll-ui-builder',
  title: I18n.t("poll.ui_builder.title")
});
