import Mixin from "@ember/object/mixin";
import deprecated from "discourse-common/lib/deprecated";
import showModal from "discourse/lib/show-modal";

export default Mixin.create({
  init() {
    this._super(...arguments);
    deprecated(
      "`modal-functionality` mixin is deprecated. Extend `modal` controller (`discourse/controllers/modal`) instead.",
      {
        id: "modal-functionality",
        since: "3.1.0.beta3",
      }
    );
  },

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
