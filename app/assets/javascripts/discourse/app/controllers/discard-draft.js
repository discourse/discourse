import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  actions: {
    destroyDraft() {
      this.onDestroyDraft();
      this.send("closeModal");
    },
    saveDraftAndClose() {
      this.onSaveDraft();
      this.send("closeModal");
    },
    dismissModal() {
      this.onDismissModal();
      this.send("closeModal");
    },
  },
});
