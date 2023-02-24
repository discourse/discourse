import Modal from "discourse/controllers/modal";

export default Modal.extend({
  actions: {
    dismiss() {
      this.send("closeModal");
      this.dismissNotifications();
    },
  },
});
