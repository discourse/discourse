import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { extractError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, {
  duration: null,
  saving: false,

  @discourseComputed("saving", "duration")
  saveDisabled(saving, duration) {
    return saving || !duration;
  },

  @action
  setDuration(duration) {
    this.set("duration", duration);
  },

  @action
  save() {
    this.set("saving", true);
    this.currentUser
      .enterDoNotDisturbFor(this.duration)
      .then(() => {
        this.send("closeModal");
      })
      .catch((e) => {
        this.flash(extractError(e), "error");
      })
      .finally(() => {
        this.set("saving", false);
      });
  },
});
