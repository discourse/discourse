import { action } from "@ember/object";
import BufferedContent from "discourse/mixins/buffered-content";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { extractError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, BufferedContent, {
  newDescription: null,

  @action
  performUpdateDescription() {
    this.model
      .update({ description: this.newDescription })
      .then((result) => {
        this.send("closeModal");

        if (result.responseJson.tag) {
          this.model.set("description", result.responseJson.tag.description);
          this.transitionToRoute("tag.show", result.responseJson.tag.id);
        } else {
          this.flash(extractError(result.responseJson.errors[0]), "error");
        }
      })
      .catch((error) => this.flash(extractError(error), "error"));
  },
});
