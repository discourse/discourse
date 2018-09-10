import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Ember.Controller.extend(ModalFunctionality, {
  onShow() {
    this.set("modal.modalClass", "keyboard-shortcuts-modal");
  }
});
