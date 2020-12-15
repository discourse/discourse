import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { publishDoNotDisturbOnFor } from "discourse/lib/do-not-disturb";

export default Controller.extend(ModalFunctionality, {
  duration: null,
  error: null,
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
    publishDoNotDisturbOnFor(this.currentUser, this.duration)
      .then(() => {
        this.send("closeModal");
      })
      .catch((e) => {
        this.set("error", e.jqXHR.responseJSON.errors[0]);
      })
      .finally(() => {
        this.set("saving", false);
      });
  },
});
