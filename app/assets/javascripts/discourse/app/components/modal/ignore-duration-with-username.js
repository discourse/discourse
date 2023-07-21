import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import User from "discourse/models/user";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { timeShortcuts } from "discourse/lib/time-shortcut";

export default class IgnoreDurationModal extends Component {
  @service currentUser;

  @tracked flash;

  @tracked loading = false;
  @tracked ignoredUntil = null;
  @tracked ignoredUsername = null;

  get timeShortcuts() {
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
  }

  @action
  ignore() {
    if (!this.ignoredUntil || !this.ignoredUsername) {
      this.flash = I18n.t(
        "user.user_notifications.ignore_duration_time_frame_required"
      );
      return;
    }
    this.loading = true;
    User.findByUsername(this.ignoredUsername).then((user) => {
      user
        .updateNotificationLevel({
          level: "ignore",
          expiringAt: this.ignoredUntil,
          actingUser: this.args.model.actingUser,
        })
        .then(() => {
          this.args.model.onUserIgnored(this.ignoredUsername);
          this.args.closeModal();
        })
        .catch(popupAjaxError)
        .finally(() => (this.loading = false));
    });
  }

  @action
  updateIgnoredUsername(selected) {
    this.ignoredUsername = selected.firstObject;
  }
}
