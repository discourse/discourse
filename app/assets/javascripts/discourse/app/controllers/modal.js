import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import showModal from "discourse/lib/show-modal";

export default Controller.extend({
  appEvents: service(),

  flash(text, messageClass) {
    this.appEvents.trigger("modal-body:flash", { text, messageClass });
  },

  clearFlash() {
    this.appEvents.trigger("modal-body:clearFlash");
  },

  showModal(...args) {
    return showModal(...args);
  },

  @action
  closeModal() {
    this.modal.send("closeModal");
    this.set("panels", []);
  },
});
