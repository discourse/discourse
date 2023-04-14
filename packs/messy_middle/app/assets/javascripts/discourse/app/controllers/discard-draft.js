import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  actions: {
    async destroyDraft() {
      await this.onDestroyDraft();
      this.send("closeModal");
    },

    async saveDraftAndClose() {
      await this.onSaveDraft();
      this.send("closeModal");
    },

    async dismissModal() {
      await this.onDismissModal();
      this.send("closeModal");
    },
  },
});
