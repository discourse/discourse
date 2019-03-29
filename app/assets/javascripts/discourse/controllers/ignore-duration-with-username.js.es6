import ModalFunctionality from "discourse/mixins/modal-functionality";
import {popupAjaxError} from "discourse/lib/ajax-error";
import User from "discourse/models/user";

export default Ember.Controller.extend(ModalFunctionality, {
  loading: false,
  ignoredUntil: null,
  ignoredUsername: null,
  actions: {
    ignore() {
      if (!this.get("ignoredUntil") || !this.get("ignoredUsername")) {
        this.flash(
          I18n.t("user.user_notifications.ignore_duration_time_frame_required"),
          "alert-error"
        );
        return;
      }
      this.set("loading", true);
      User.findByUsername(this.get("ignoredUsername")).then(user => {
        user
          .updateNotificationLevel("ignore", this.get("ignoredUntil"))
          .then(() => {
            this.get("onSuccess")(this.get("ignoredUsername"));
            this.send("closeModal");
          })
          .catch(popupAjaxError)
          .finally(() => this.set("loading", false));
      });
    }
  }
});
