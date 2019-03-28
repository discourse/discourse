import ModalFunctionality from "discourse/mixins/modal-functionality";
import {popupAjaxError} from "discourse/lib/ajax-error";

export default Ember.Controller.extend(ModalFunctionality, {
  loading: false,
  ignoredUntil: null,
  maxDate: moment().utc().add(4, "months").toDate(),
  actions: {
    ignore() {
      if (!this.get("ignoredUntil")) {
        this.flash(
          I18n.t("user.user_notifications.ignore_duration_time_frame_required"),
          "alert-error"
        );
        return;
      }
      this.set("loading", true);
      this.get("model")
        .updateNotificationLevel("ignore", this.get("ignoredUntil"))
        .then(() => {
          this.set("model.ignored", true);
          this.set("model.muted", false);
          if (this.get("onSuccess")) {
            this.get("onSuccess")();
          }
          this.send("closeModal");
        })
        .catch(popupAjaxError)
        .finally(() => this.set("loading", false));
    }
  }
});
