import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  onShow() {
    this.set("updateExistingUsers", null);
  },

  actions: {
    updateExistingUsers() {
      this.set("updateExistingUsers", true);
      this.send("closeModal");
    },

    cancel() {
      this.set("updateExistingUsers", false);
      this.send("closeModal");
    }
  }
});
