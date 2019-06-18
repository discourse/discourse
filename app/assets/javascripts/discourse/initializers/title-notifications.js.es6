export default {
  name: "title-notifications",
  after: "message-bus",

  initialize(container) {
    const user = container.lookup("current-user:main");
    if (!user) return; // must be logged in

    this.notifications =
      user.unread_notifications + user.unread_private_messages;

    container
      .lookup("app-events:main")
      .on("notifications:changed", this, "_updateTitle");
  },

  _updateTitle() {
    Discourse.updateNotificationCount(this.notifications);
  }
};
