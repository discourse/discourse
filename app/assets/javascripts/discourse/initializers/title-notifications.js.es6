export default {
  name: "title-notifications",
  after: "message-bus",

  initialize(container) {
    const appEvents = container.lookup("app-events:main");
    const user = container.lookup("current-user:main");

    if (!user) return; // must be logged in

    appEvents.on("notifications:changed", () => {
      let notifications =
        user.unread_notifications + user.unread_private_messages;

      Discourse.updateNotificationCount(notifications);
    });
  }
};
