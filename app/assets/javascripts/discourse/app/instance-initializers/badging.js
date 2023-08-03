// Updates the PWA badging if available
export default {
  after: "message-bus",

  initialize(owner) {
    // must have the Badging API
    if (!navigator.setAppBadge) {
      return;
    }

    const user = owner.lookup("service:current-user");
    // must be logged in
    if (!user) {
      return;
    }

    const appEvents = owner.lookup("service:app-events");
    appEvents.on("notifications:changed", this, () => {
      let notifications = user.all_unread_notifications_count;

      if (user.unseen_reviewable_count) {
        notifications += user.unseen_reviewable_count;
      }

      navigator.setAppBadge(notifications);
    });
  },
};
