import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend(ModalFunctionality, {
  duration: null,
  error: null,
  saving: false,

  @discourseComputed("saving", "duration")
  saveDisabled(saving, duration) {
    return saving || duration === null;
  },

  @action
  setDuration(duration) {
    this.set("duration", duration);
  },

  @action
  save() {
    this.set("saving", true);
    ajax({
      url: "/do-not-disturb",
      type: "POST",
      data: { duration: this.duration },
    })
      .then((response) => {
        this.send("closeModal");
        this.currentUser.set("do_not_disturb_until", response.ends_at);
      })
      .catch((e) => {
        this.set("error", e[0]);
      })
      .finally(() => {
        this.set("saving", false);
      });
  },
});
