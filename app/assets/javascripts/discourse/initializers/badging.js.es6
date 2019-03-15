// Updates the PWA badging if avaliable
export default {
  name: "badging",
  after: "message-bus",

  initialize(container) {
    const appEvents = container.lookup("app-events:main");
    const user = container.lookup("current-user:main");

    if (!user) return; // must be logged in
    if (!window.ExperimentalBadge) return; // must have the Badging API

    appEvents.on("notifications:changed", () => {
      let notifications =
        user.get("unread_notifications") + user.get("unread_private_messages");
      window.ExperimentalBadge.set(notifications);
    });
  }
};
