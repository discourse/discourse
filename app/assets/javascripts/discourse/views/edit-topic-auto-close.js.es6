import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: "modal/edit-topic-auto-close",
  title: I18n.t("topic.auto_close_title"),
  focusInput: false
});
