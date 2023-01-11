import Controller from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { timeShortcuts } from "discourse/lib/time-shortcut";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  ignoredUntil: null,

  @discourseComputed
  timeShortcuts() {
    const timezone = this.currentUser.user_option.timezone;
    const shortcuts = timeShortcuts(timezone);
    return [
      shortcuts.laterToday(),
      shortcuts.tomorrow(),
      shortcuts.laterThisWeek(),
      shortcuts.thisWeekend(),
      shortcuts.monday(),
      shortcuts.twoWeeks(),
      shortcuts.nextMonth(),
      shortcuts.twoMonths(),
      shortcuts.threeMonths(),
      shortcuts.fourMonths(),
      shortcuts.sixMonths(),
      shortcuts.oneYear(),
      shortcuts.forever(),
    ];
  },

  actions: {
    ignore() {
      if (!this.ignoredUntil) {
        this.flash(
          I18n.t("user.user_notifications.ignore_duration_time_frame_required"),
          "error"
        );
        return;
      }
      this.set("loading", true);
      this.model
        .updateNotificationLevel({
          level: "ignore",
          expiringAt: this.ignoredUntil,
        })
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
