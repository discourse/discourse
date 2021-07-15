import EmberObject, { set } from "@ember/object";
// Subscribes to user events on the message bus
import {
  alertChannel,
  disable as disableDesktopNotifications,
  init as initDesktopNotifications,
  onNotification,
} from "discourse/lib/desktop-notifications";
import {
  isPushNotificationsEnabled,
  register as registerPushNotifications,
  unsubscribe as unsubscribePushNotifications,
} from "discourse/lib/push-notifications";
import { isTesting } from "discourse-common/config/environment";

export default {
  name: "subscribe-user-notifications",
  after: "message-bus",

  initialize(container) {
    const user = container.lookup("current-user:main");
    const bus = container.lookup("message-bus:main");
    const appEvents = container.lookup("service:app-events");

    if (user) {
      bus.subscribe("/reviewable_counts", (data) => {
        user.set("reviewable_count", data.reviewable_count);
      });

      bus.subscribe(
        `/notification/${user.get("id")}`,
        (data) => {
          const store = container.lookup("service:store");
          const oldUnread = user.get("unread_notifications");
          const oldHighPriority = user.get(
            "unread_high_priority_notifications"
          );

          user.setProperties({
            unread_notifications: data.unread_notifications,
            unread_high_priority_notifications:
              data.unread_high_priority_notifications,
            read_first_notification: data.read_first_notification,
          });

          if (
            oldUnread !== data.unread_notifications ||
            oldHighPriority !== data.unread_high_priority_notifications
          ) {
            appEvents.trigger("notifications:changed");

            if (
              site.mobileView &&
              (data.unread_notifications - oldUnread > 0 ||
                data.unread_high_priority_notifications - oldHighPriority > 0)
            ) {
              appEvents.trigger("header:update-topic", null, 5000);
            }
          }

          const stale = store.findStale(
            "notification",
            {},
            { cacheKey: "recent-notifications" }
          );
          const lastNotification =
            data.last_notification && data.last_notification.notification;

          if (stale && stale.hasResults && lastNotification) {
            const oldNotifications = stale.results.get("content");
            const staleIndex = oldNotifications.findIndex(
              (n) => n.id === lastNotification.id
            );

            if (staleIndex === -1) {
              // high priority and unread notifications are first
              let insertPosition = 0;

              if (!lastNotification.high_priority || lastNotification.read) {
                const nextPosition = oldNotifications.findIndex(
                  (n) => !n.high_priority || n.read
                );

                if (nextPosition !== -1) {
                  insertPosition = nextPosition;
                }
              }

              oldNotifications.insertAt(
                insertPosition,
                EmberObject.create(lastNotification)
              );
            }

            // remove stale notifications and update existing ones
            const read = Object.fromEntries(data.recent);
            const newNotifications = oldNotifications
              .map((notification) => {
                if (read[notification.id] !== undefined) {
                  notification.set("read", read[notification.id]);
                  return notification;
                }
              })
              .filter(Boolean);
            stale.results.set("content", newNotifications);
          }
        },
        user.notification_channel_position
      );

      bus.subscribe(`/do-not-disturb/${user.get("id")}`, (data) => {
        user.updateDoNotDisturbStatus(data.ends_at);
      });

      const site = container.lookup("site:main");
      const siteSettings = container.lookup("site-settings:main");
      const router = container.lookup("router:main");

      bus.subscribe("/categories", (data) => {
        (data.categories || []).forEach((c) => site.updateCategory(c));
        (data.deleted_categories || []).forEach((id) =>
          site.removeCategory(id)
        );
      });

      bus.subscribe("/client_settings", (data) =>
        set(siteSettings, data.name, data.value)
      );

      if (!isTesting()) {
        bus.subscribe(alertChannel(user), (data) =>
          onNotification(data, siteSettings, user)
        );
        initDesktopNotifications(bus, appEvents);

        if (isPushNotificationsEnabled(user, site.mobileView)) {
          disableDesktopNotifications();
          registerPushNotifications(user, site.mobileView, router, appEvents);
        } else {
          unsubscribePushNotifications(user);
        }
      }
    }
  },
};
