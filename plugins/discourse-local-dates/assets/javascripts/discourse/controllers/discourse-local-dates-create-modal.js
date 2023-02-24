import Modal from "discourse/controllers/modal";
import { schedule } from "@ember/runloop";

export default Modal.extend({
  onShow() {
    schedule("afterRender", () => {
      const fromButton = document.getElementById("from-date-time");
      fromButton && fromButton.focus();
    });
  },

  onClose() {
    schedule("afterRender", () => {
      const localDatesBtn = document.querySelector(
        ".d-editor-button-bar .local-dates.btn"
      );
      localDatesBtn && localDatesBtn.focus();
    });
  },
});
