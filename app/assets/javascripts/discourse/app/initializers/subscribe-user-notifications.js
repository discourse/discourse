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
import Notification from "discourse/models/notification";

export default {
  name: "subscribe-user-notifications",
  after: "message-bus",

  initialize(container) {
    const user = container.lookup("service:current-user");
    const bus = container.lookup("service:message-bus");
    const appEvents = container.lookup("service:app-events");
    const siteSettings = container.lookup("service:site-settings");

    if (user) {
      const channel = user.redesigned_user_menu_enabled
        ? `/reviewable_counts/${user.id}`
        : "/reviewable_counts";

      bus.subscribe(channel, (data) => {
        if (data.reviewable_count >= 0) {
          user.updateReviewableCount(data.reviewable_count);
        }

        if (user.redesigned_user_menu_enabled) {
          user.set("unseen_reviewable_count", data.unseen_reviewable_count);
        }
      });

      bus.subscribe(
        `/notification/${user.id}`,
        (data) => {
          const store = container.lookup("service:store");
          const oldUnread = user.unread_notifications;
          const oldHighPriority = user.unread_high_priority_notifications;
          const oldAllUnread = user.all_unread_notifications_count;

          user.setProperties({
            unread_notifications: data.unread_notifications,
            unread_high_priority_notifications:
              data.unread_high_priority_notifications,
            read_first_notification: data.read_first_notification,
            all_unread_notifications_count: data.all_unread_notifications_count,
            grouped_unread_notifications: data.grouped_unread_notifications,
            new_personal_messages_notifications_count:
              data.new_personal_messages_notifications_count,
          });

          if (
            oldUnread !== data.unread_notifications ||
            oldHighPriority !== data.unread_high_priority_notifications ||
            oldAllUnread !== data.all_unread_notifications_count
          ) {
            appEvents.trigger("notifications:changed");

            if (
              site.mobileView &&
              (data.unread_notifications - oldUnread > 0 ||
                data.unread_high_priority_notifications - oldHighPriority > 0 ||
                data.all_unread_notifications_count - oldAllUnread > 0)
            ) {
              appEvents.trigger("header:update-topic", null, 5000);
            }
          }

          const stale = store.findStale(
            "notification",
            {},
            { cacheKey: "recent-notifications" }
          );
          const lastNotification = data.last_notification?.notification;

          if (stale?.hasResults && lastNotification) {
            const oldNotifications = stale.results.get("content");
            const staleIndex = oldNotifications.findIndex(
              (n) => n.id === lastNotification.id
            );

            if (staleIndex === -1) {
              let insertPosition = 0;

              // high priority and unread notifications are first
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
                Notification.create(lastNotification)
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

      bus.subscribe(`/user-drafts/${user.id}`, (data) => {
        user.updateDraftProperties(data);
      });

      bus.subscribe(`/do-not-disturb/${user.get("id")}`, (data) => {
        user.updateDoNotDisturbStatus(data.ends_at);
      });

      bus.subscribe(`/user-status`, (data) => {
        appEvents.trigger("user-status:changed", data);
      });

      const site = container.lookup("service:site");
      const router = container.lookup("router:main");

      bus.subscribe("/categories", (data) => {
        (data.categories || []).forEach((c) => {
          const mutedCategoryIds = user.muted_category_ids?.concat(
            user.indirectly_muted_category_ids
          );
          if (
            mutedCategoryIds &&
            mutedCategoryIds.includes(c.parent_category_id) &&
            !mutedCategoryIds.includes(c.id)
          ) {
            user.set(
              "indirectly_muted_category_ids",
              user.indirectly_muted_category_ids.concat(c.id)
            );
          }
          return site.updateCategory(c);
        });

        (data.deleted_categories || []).forEach((id) =>
          site.removeCategory(id)
        );
      });

      bus.subscribe(
        "/client_settings",
        (data) => (siteSettings[data.name] = data.value)
      );

      if (!isTesting()) {
        bus.subscribe(alertChannel(user), (data) =>
          onNotification(data, siteSettings, user)
        );

        initDesktopNotifications(bus, appEvents);

        if (isPushNotificationsEnabled(user)) {
          disableDesktopNotifications();
          registerPushNotifications(user, router, appEvents);
        } else {
          unsubscribePushNotifications(user);
        }
      }
    }
  },
};
