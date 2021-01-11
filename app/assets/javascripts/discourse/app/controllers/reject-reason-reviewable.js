import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  onShow() {
    this.setProperties({ rejectReason: "", sendEmail: false });
  },

  actions: {
    perform() {
      this.model.set("rejectReason", this.rejectReason);
      this.send("closeModal");
      this.performConfirmed(this.action);
    },
  },
});
