import Controller from "@ember/controller";
import { action } from "@ember/object";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
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
