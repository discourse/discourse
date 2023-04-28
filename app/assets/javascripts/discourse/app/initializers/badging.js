// Updates the PWA badging if available
export default {
  name: "badging",
  after: "message-bus",

  initialize(container) {
    if (!navigator.setAppBadge) {
      return;
    } // must have the Badging API

    const user = container.lookup("service:current-user");
    if (!user) {
      return;
    } // must be logged in

    const appEvents = container.lookup("service:app-events");
    appEvents.on("notifications:changed", () => {
      let notifications;
      notifications = user.all_unread_notifications_count;
      if (user.unseen_reviewable_count) {
        notifications += user.unseen_reviewable_count;
      }

      navigator.setAppBadge(notifications);
    });
  },
};
