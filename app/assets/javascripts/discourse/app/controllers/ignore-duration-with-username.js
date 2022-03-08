import Controller from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import User from "discourse/models/user";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  ignoredUntil: null,
  ignoredUsername: null,
  actions: {
    ignore() {
      if (!this.ignoredUntil || !this.ignoredUsername) {
        this.flash(
          I18n.t("user.user_notifications.ignore_duration_time_frame_required"),
          "error"
        );
        return;
      }
      this.set("loading", true);
      User.findByUsername(this.ignoredUsername).then((user) => {
        user
          .updateNotificationLevel("ignore", this.ignoredUntil, this.model)
          .then(() => {
            this.onUserIgnored(this.ignoredUsername);
            this.send("closeModal");
          })
          .catch(popupAjaxError)
          .finally(() => this.set("loading", false));
      });
    },

    updateIgnoredUsername(selected) {
      this.set("ignoredUsername", selected.firstObject);
    },
  },
});
