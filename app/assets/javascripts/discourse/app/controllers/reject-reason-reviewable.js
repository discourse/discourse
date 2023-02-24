import Modal from "discourse/controllers/modal";
import { action } from "@ember/object";

export default Modal.extend({
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
