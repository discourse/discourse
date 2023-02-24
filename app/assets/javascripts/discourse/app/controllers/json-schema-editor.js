import { action } from "@ember/object";
import Modal from "discourse/controllers/modal";

export default Modal.extend({
  editor: null,

  @action
  saveChanges(value) {
    this.set("model.value", value);
    this.send("closeModal");
  },
});
