// Updates the PWA badging if available
export default {
  after: "message-bus",

  initialize(owner) {
    if (!navigator.setAppBadge) {
      return;
    } // must have the Badging API

    const user = owner.lookup("service:current-user");
    if (!user) {
      return;
    } // must be logged in

    const appEvents = owner.lookup("service:app-events");
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
