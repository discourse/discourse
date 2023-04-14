import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";

export default Controller.extend(ModalFunctionality, {
  rejectReason: null,
  sendEmail: false,

  onShow() {
    this.setProperties({ rejectReason: null, sendEmail: false });
  },

  @action
  perform() {
    this.model.setProperties({
      rejectReason: this.rejectReason,
      sendEmail: this.sendEmail,
    });
    this.send("closeModal");
    this.performConfirmed(this.action);
  },
});
