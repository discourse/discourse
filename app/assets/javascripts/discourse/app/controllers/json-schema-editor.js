import { action } from "@ember/object";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  editor: null,

  @action
  saveChanges(value) {
    this.set("model.value", value);
    this.send("closeModal");
  },
});
