import { action } from "@ember/object";
import Modal from "discourse/controllers/modal";

export default Modal.extend({
  data: null,

  onShow() {
    this.set("data", null);
  },

  onClose() {
    if (this.data) {
      this.data.abort();
      this.set("data", null);
    }
  },

  @action
  submit(data) {
    this.set("data", data);
    data.submit();
  },
});
