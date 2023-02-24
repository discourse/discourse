import Modal from "discourse/controllers/modal";

export default Modal.extend({
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
