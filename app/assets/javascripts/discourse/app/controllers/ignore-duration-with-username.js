import I18n from "I18n";
import Modal from "discourse/controllers/modal";
import User from "discourse/models/user";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { timeShortcuts } from "discourse/lib/time-shortcut";
import discourseComputed from "discourse-common/utils/decorators";

export default Modal.extend({
  loading: false,
  ignoredUntil: null,
  ignoredUsername: null,

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
          .updateNotificationLevel({
            level: "ignore",
            expiringAt: this.ignoredUntil,
            actingUser: this.model,
          })
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
