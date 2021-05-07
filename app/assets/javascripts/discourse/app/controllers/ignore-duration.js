import Controller from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { additionalTimeframeOptions } from "discourse/lib/time-shortcut";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  ignoredUntil: null,
  userTimezone: null,

  onShow() {
    this.set(
      "userTimezone",
      this.currentUser.resolvedTimezone(this.currentUser)
    );
  },

  @discourseComputed("userTimezone")
  customTimeframeOptions(userTimezone) {
    const options = additionalTimeframeOptions(userTimezone);
    return [
      options.twoWeeks(),
      options.twoMonths(),
      options.threeMonths(),
      options.fourMonths(),
      options.sixMonths(),
      options.oneYear(),
      options.forever(),
    ];
  },

  actions: {
    ignore() {
      if (!this.ignoredUntil) {
        this.flash(
          I18n.t("user.user_notifications.ignore_duration_time_frame_required"),
          "alert-error"
        );
        return;
      }
      this.set("loading", true);
      this.model
        .updateNotificationLevel("ignore", this.ignoredUntil)
        .then(() => {
          this.set("model.ignored", true);
          this.set("model.muted", false);
          if (this.onSuccess) {
            this.onSuccess();
          }
          this.send("closeModal");
        })
        .catch(popupAjaxError)
        .finally(() => this.set("loading", false));
    },
  },
});
