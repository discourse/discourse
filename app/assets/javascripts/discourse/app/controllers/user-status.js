import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";

export default Controller.extend(ModalFunctionality, {
  description: "",
  statusIsSet: notEmpty("description"),
  showDeleteButton: false,

  onShow() {
    if (this.currentUser.status?.description) {
      this.setProperties({
        description: this.currentUser.status?.description,
        showDeleteButton: true,
      });
    }
  },

  @action
  delete() {
    this.set("description", "");
    this.currentUser.status = null;
    this.send("closeModal");
  },

  @action
  saveAndClose() {
    if (this.description) {
      this.currentUser.status = {
        emoji: "mega",
        description: this.description,
      };
    }

    this.send("closeModal");
  },
});
