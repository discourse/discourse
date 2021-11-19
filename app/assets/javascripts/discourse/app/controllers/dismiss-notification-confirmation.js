import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  actions: {
    confirm() {
      this.send("closeModal");
      this.dismissNotifications();
    },
  },
});
