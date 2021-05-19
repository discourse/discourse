import Mixin from "@ember/object/mixin";
import showModal from "discourse/lib/show-modal";

export default Mixin.create({
  flash(text, messageClass) {
    this.appEvents.trigger("modal-body:flash", { text, messageClass });
  },

  clearFlash() {
    this.appEvents.trigger("modal-body:clearFlash");
  },

  showModal(...args) {
    return showModal(...args);
  },

  actions: {
    closeModal() {
      this.modal.send("closeModal");
      this.set("panels", []);
    },
  },
});
