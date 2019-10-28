import EmberObject from "@ember/object";
// Subscribes to user events on the message bus
import {
  init as initDesktopNotifications,
  onNotification,
  alertChannel,
  disable as disableDesktopNotifications
} from "discourse/lib/desktop-notifications";
import {
  register as registerPushNotifications,
  unsubscribe as unsubscribePushNotifications,
  isPushNotificationsEnabled
} from "discourse/lib/push-notifications";

export default {
  name: "subscribe-user-notifications",
  after: "message-bus",

  initialize(container) {
    const user = container.lookup("current-user:main");
    const bus = container.lookup("message-bus:main");
    const appEvents = container.lookup("service:app-events");

    if (user) {
      bus.subscribe("/reviewable_counts", data => {
        user.set("reviewable_count", data.reviewable_count);
      });

      bus.subscribe(
        `/notification/${user.get("id")}`,
        data => {
          const store = container.lookup("service:store");
          const oldUnread = user.get("unread_notifications");
          const oldPM = user.get("unread_private_messages");

          user.setProperties({
            unread_notifications: data.unread_notifications,
            unread_private_messages: data.unread_private_messages,
            read_first_notification: data.read_first_notification
          });

          if (
            oldUnread !== data.unread_notifications ||
            oldPM !== data.unread_private_messages
          ) {
            appEvents.trigger("notifications:changed");

            if (
              site.mobileView &&
              (data.unread_notifications - oldUnread > 0 ||
                data.unread_private_messages - oldPM > 0)
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
            const staleIndex = _.findIndex(oldNotifications, {
              id: lastNotification.id
            });

            if (staleIndex === -1) {
              // this gets a bit tricky, unread pms are bumped to front
              let insertPosition = 0;
              if (lastNotification.notification_type !== 6) {
                insertPosition = _.findIndex(
                  oldNotifications,
                  n => n.notification_type !== 6 || n.read
                );
                insertPosition =
                  insertPosition === -1
                    ? oldNotifications.length - 1
                    : insertPosition;
              }
              oldNotifications.insertAt(
                insertPosition,
                EmberObject.create(lastNotification)
              );
            }

            for (let idx = 0; idx < data.recent.length; idx++) {
              let old;
              while ((old = oldNotifications[idx])) {
                const info = data.recent[idx];

                if (old.get("id") !== info[0]) {
                  oldNotifications.removeAt(idx);
                } else {
                  if (old.get("read") !== info[1]) {
                    old.set("read", info[1]);
                  }
                  break;
                }
              }
              if (!old) {
                break;
              }
            }
          }
        },
        user.notification_channel_position
      );

      const site = container.lookup("site:main");
      const siteSettings = container.lookup("site-settings:main");
      const router = container.lookup("router:main");

      bus.subscribe("/categories", data => {
        (data.categories || []).forEach(c => site.updateCategory(c));
        (data.deleted_categories || []).forEach(id => site.removeCategory(id));
      });

      bus.subscribe("/client_settings", data =>
        Ember.set(siteSettings, data.name, data.value)
      );
      bus.subscribe("/refresh_client", data =>
        Discourse.set("assetVersion", data)
      );

      if (!Ember.testing) {
        bus.subscribe(alertChannel(user), data => onNotification(data, user));
        initDesktopNotifications(bus, appEvents);

        if (isPushNotificationsEnabled(user, site.mobileView)) {
          disableDesktopNotifications();
          registerPushNotifications(user, site.mobileView, router, appEvents);
        } else {
          unsubscribePushNotifications(user);
        }
      }
    }
  }
};
