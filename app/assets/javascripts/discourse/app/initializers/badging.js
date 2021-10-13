// Updates the PWA badging if available

let defaultBadgingDisabled = false;
export function disableDefaultBadging() {
  defaultBadgingDisabled = true;
}

export default {
  name: "badging",
  after: "message-bus",

  initialize(container) {
    // must have the Badging API
    if (defaultBadgingDisabled || !navigator.setAppBadge) {
      return;
    }

    const user = container.lookup("current-user:main");
    if (!user) {
      return;
    } // must be logged in

    this.notifications =
      user.unread_notifications + user.unread_high_priority_notifications;

    container
      .lookup("service:app-events")
      .on("notifications:changed", this, "_updateBadge");
  },

  _updateBadge() {
    navigator.setAppBadge(this.notifications);
  },
};
