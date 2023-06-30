import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  showSaveDraftButton: true,

  actions: {
    async destroyDraft() {
      await this.onDestroyDraft();
      this.send("closeModal");
    },

    async saveDraftAndClose() {
      await this.onSaveDraft();
      this.send("closeModal");
    },

    dismissModal() {
      this.send("closeModal");
    },
  },
});
