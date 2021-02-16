import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";

export default Controller.extend(ModalFunctionality, {
  onShow() {
    this.setProperties({
      model: this.model || {},
      allowSave: true,
    });
  },

  @action
  registerOnCloseHandler(handlerFn) {
    this.set("onCloseHandler", handlerFn);
  },

  /**
   * We always want to save the bookmark unless the user specifically
   * clicks the save or cancel button to mimic browser behaviour.
   */
  onClose(opts = {}) {
    if (this.onCloseHandler) {
      this.onCloseHandler(opts.initiatedByCloseButton);
    }
  },
});
