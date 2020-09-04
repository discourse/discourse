import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { schedule } from "@ember/runloop";

export default Controller.extend(ModalFunctionality, {
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
