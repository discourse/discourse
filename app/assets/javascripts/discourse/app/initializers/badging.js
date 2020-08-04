// Updates the PWA badging if avaliable
export default {
  name: "badging",
  after: "message-bus",

  initialize(container) {
    if (!navigator.setAppBadge) return; // must have the Badging API

    const user = container.lookup("current-user:main");
    if (!user) return; // must be logged in

    this.notifications =
      user.unread_notifications + user.unread_high_priority_notifications;

    container
      .lookup("service:app-events")
      .on("notifications:changed", this, "_updateBadge");
  },

  _updateBadge() {
    navigator.setAppBadge(this.notifications);
  }
};
