import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { popupAjaxError } from "discourse/lib/ajax-error";
import User from "discourse/models/user";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  ignoredUntil: null,
  ignoredUsername: null,
  actions: {
    ignore() {
      if (!this.ignoredUntil || !this.ignoredUsername) {
        this.flash(
          I18n.t("user.user_notifications.ignore_duration_time_frame_required"),
          "alert-error"
        );
        return;
      }
      this.set("loading", true);
      User.findByUsername(this.ignoredUsername).then(user => {
        user
          .updateNotificationLevel("ignore", this.ignoredUntil)
          .then(() => {
            this.onUserIgnored(this.ignoredUsername);
            this.send("closeModal");
          })
          .catch(popupAjaxError)
          .finally(() => this.set("loading", false));
      });
    }
  }
});
