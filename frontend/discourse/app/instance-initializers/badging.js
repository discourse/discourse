import { lookup } from "discourse/lib/service";
import CurrentUserService from "discourse/services/current-user";
import AppEventsService from "discourse/services/app-events";
// Updates the PWA badging if available
export default {
  after: "message-bus",

  initialize(owner) {
    if (!navigator.setAppBadge) {
      return;
    } // must have the Badging API

    const user = lookup(owner, CurrentUserService);
    if (!user) {
      return;
    } // must be logged in

    const appEvents = lookup(owner, AppEventsService);
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
