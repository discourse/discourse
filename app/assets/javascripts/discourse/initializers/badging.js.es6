// Updates the PWA badging if avaliable
export default {
  name: "badging",
  after: "message-bus",

  initialize(container) {
    if (!window.ExperimentalBadge) return; // must have the Badging API

    const user = container.lookup("current-user:main");
    if (!user) return; // must be logged in

    this.notifications =
      user.unread_notifications + user.unread_private_messages;

    container
      .lookup("app-events:main")
      .on("notifications:changed", this, "_updateBadge");
  },

  _updateBadge() {
    window.ExperimentalBadge.set(this.notifications);
  }
};
