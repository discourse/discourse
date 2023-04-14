import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { flashAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, {
  duration: null,

  @action
  setDuration(duration) {
    this.set("duration", duration);
    this.save();
  },

  save() {
    this.currentUser
      .enterDoNotDisturbFor(this.duration)
      .then(() => {
        this.send("closeModal");
      })
      .catch(flashAjaxError(this));
  },

  @action
  navigateToNotificationSchedule() {
    this.transitionToRoute("preferences.notifications", this.currentUser);
    this.send("closeModal");
  },
});
