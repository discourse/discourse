// Subscribes to user events on the message bus
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import {
  alertChannel,
  disable as disableDesktopNotifications,
  init as initDesktopNotifications,
  onNotification as onDesktopNotification,
} from "discourse/lib/desktop-notifications";
import EmbedMode from "discourse/lib/embed-mode";
import { isTesting } from "discourse/lib/environment";
import { getRenderDirector } from "discourse/lib/notification-types-manager";
import {
  isPushNotificationsEnabled,
  register as registerPushNotifications,
  unsubscribe as unsubscribePushNotifications,
} from "discourse/lib/push-notifications";
import { currentThemeId } from "discourse/lib/theme-selector";
import DiscourseURL from "discourse/lib/url";
import Notification from "discourse/models/notification";
import { i18n } from "discourse-i18n";

const NOTIFICATION_TOAST_CLASS = "desktop-notification-toast";

class SubscribeUserNotificationsInit {
  @service appEvents;
  @service capabilities;
  @service currentUser;
  @service messageBus;
  @service pmTopicTrackingState;
  @service router;
  @service site;
  @service siteSettings;
  @service store;
  @service toasts;

  #lastObservedNotificationId = 0;

  constructor(owner) {
    setOwner(this, owner);

    if (!this.currentUser) {
      return;
    }

    this.reviewableCountsChannel = `/reviewable_counts/${this.currentUser.id}`;

    this.messageBus.subscribe(
      this.reviewableCountsChannel,
      this.onReviewableCounts
    );

    this.messageBus.subscribe(
      `/notification/${this.currentUser.id}`,
      this.onNotification,
      this.currentUser.notification_channel_position
    );

    this.messageBus.subscribe(
      `/user-drafts/${this.currentUser.id}`,
      this.onUserDrafts
    );

    this.messageBus.subscribe(
      `/do-not-disturb/${this.currentUser.id}`,
      this.onDoNotDisturb,
      this.currentUser.do_not_disturb_channel_position
    );

    this.messageBus.subscribe(
      `/user-status`,
      this.onUserStatus,
      this.currentUser.status?.message_bus_last_id
    );

    this.messageBus.subscribe("/categories", this.onCategories);

    this.messageBus.subscribe("/client_settings", this.onClientSettings);

    if (!EmbedMode.enabled) {
      this.pmTopicTrackingState.startTracking();
    }

    if (!isTesting()) {
      this.messageBus.subscribe(alertChannel(this.currentUser), this.onAlert);

      initDesktopNotifications(this.messageBus);

      if (isPushNotificationsEnabled(this.currentUser)) {
        disableDesktopNotifications();
        registerPushNotifications(
          this.currentUser,
          this.router,
          this.appEvents
        );
      } else if (!this.currentUser.isInDoNotDisturb()) {
        unsubscribePushNotifications(this.currentUser);
      }
    }
  }

  teardown() {
    if (!this.currentUser) {
      return;
    }

    this.messageBus.unsubscribe(
      this.reviewableCountsChannel,
      this.onReviewableCounts
    );

    this.messageBus.unsubscribe(
      `/notification/${this.currentUser.id}`,
      this.onNotification
    );

    this.messageBus.unsubscribe(
      `/user-drafts/${this.currentUser.id}`,
      this.onUserDrafts
    );

    this.messageBus.unsubscribe(
      `/do-not-disturb/${this.currentUser.id}`,
      this.onDoNotDisturb
    );

    this.messageBus.unsubscribe(`/user-status`, this.onUserStatus);

    this.messageBus.unsubscribe("/categories", this.onCategories);

    this.messageBus.unsubscribe("/client_settings", this.onClientSettings);

    this.messageBus.unsubscribe(alertChannel(this.currentUser), this.onAlert);
  }

  @bind
  onReviewableCounts(data) {
    if (data.reviewable_count >= 0) {
      this.currentUser.updateReviewableCount(data.reviewable_count);
    }

    this.currentUser.set(
      "unseen_reviewable_count",
      data.unseen_reviewable_count
    );
  }

  @bind
  onNotification(data) {
    const oldUnread = this.currentUser.unread_notifications;
    const oldHighPriority = this.currentUser.unread_high_priority_notifications;
    const oldAllUnread = this.currentUser.all_unread_notifications_count;

    if ("available_notification_types" in data) {
      this.currentUser.set(
        "available_notification_types",
        data.available_notification_types
      );
    }

    this.currentUser.setProperties({
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
      this.appEvents.trigger("notifications:changed");

      if (
        this.site.mobileView &&
        (data.unread_notifications - oldUnread > 0 ||
          data.unread_high_priority_notifications - oldHighPriority > 0 ||
          data.all_unread_notifications_count - oldAllUnread > 0)
      ) {
        this.appEvents.trigger("header:update-topic", null, 5000);
      }
    }

    const stale = this.store.findStale(
      "notification",
      {},
      { cacheKey: "recent-notifications" }
    );
    const lastNotification = data.last_notification?.notification;

    this.#maybeShowNotificationToast(lastNotification, data, oldAllUnread);

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

        oldNotifications.splice(
          insertPosition,
          0,
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
  }

  @bind
  onUserDrafts(data) {
    this.currentUser.updateDraftProperties(data);
  }

  @bind
  onDoNotDisturb(data) {
    this.currentUser.updateDoNotDisturbStatus(data.ends_at);
  }

  @bind
  onUserStatus(data) {
    this.appEvents.trigger("user-status:changed", data);
  }

  @bind
  onCategories(data) {
    (data.categories || []).forEach((c) => {
      const mutedCategoryIds = this.currentUser.muted_category_ids?.concat(
        this.currentUser.indirectly_muted_category_ids
      );

      if (
        mutedCategoryIds &&
        mutedCategoryIds.includes(c.parent_category_id) &&
        !mutedCategoryIds.includes(c.id)
      ) {
        this.currentUser.set(
          "indirectly_muted_category_ids",
          this.currentUser.indirectly_muted_category_ids.concat(c.id)
        );
      }

      return this.site.updateCategory(c);
    });

    (data.deleted_categories || []).forEach((id) =>
      this.site.removeCategory(id)
    );
  }

  @bind
  onClientSettings(data) {
    // Theme site setting changes for client settings should only affect users
    // currently using the same theme.
    if (data.scoped_to?.theme_id) {
      if (currentThemeId() !== data.scoped_to.theme_id) {
        return;
      }
    }

    this.siteSettings[data.name] = data.value;

    if (
      this.siteSettings.currentUserUpcomingChanges.hasOwnProperty(data.name)
    ) {
      this.siteSettings.currentUserUpcomingChanges[data.name] = data.value;
    }
  }

  @bind
  onAlert(data) {
    if (!this.capabilities.isMobileDevice) {
      return onDesktopNotification(
        data,
        this.siteSettings,
        this.currentUser,
        this.appEvents
      );
    }
  }

  #maybeShowNotificationToast(notification, data, oldUnreadCount) {
    if (!notification || notification.id <= this.#lastObservedNotificationId) {
      return;
    }
    this.#lastObservedNotificationId = notification.id;

    if (
      !this.siteSettings.enable_desktop_notification_toasts ||
      !this.currentUser.user_option?.show_notification_toasts ||
      this.currentUser.isInDoNotDisturb() ||
      this.site.mobileView ||
      this.capabilities.isMobileDevice ||
      EmbedMode.enabled ||
      document.visibilityState !== "visible" ||
      notification.read ||
      notification.id <= data.seen_notification_id ||
      !(data.all_unread_notifications_count > oldUnreadCount)
    ) {
      return;
    }

    const type = this.site.notificationLookup[notification.notification_type];
    const excluded =
      this.siteSettings.desktop_notification_toast_excluded_types;
    if (excluded?.split("|").includes(type)) {
      return;
    }

    const director = getRenderDirector(
      type,
      Notification.create(notification),
      this.currentUser,
      this.siteSettings,
      this.site
    );
    const active = this.toasts.activeToasts.filter(
      (toast) => toast.options.class === NOTIFICATION_TOAST_CLASS
    );
    const maxStack = this.siteSettings.desktop_notification_toast_max_stack;
    for (const toast of active.slice(
      0,
      Math.max(0, active.length - maxStack + 1)
    )) {
      this.toasts.close(toast);
    }

    const href = director.linkHref;
    const sender = director.label;
    const topic = notification.data.topic_title;
    this.toasts.default({
      class: NOTIFICATION_TOAST_CLASS,
      views: ["desktop"],
      duration:
        this.siteSettings.desktop_notification_toast_duration_seconds * 1000,
      data: {
        icon: type ? director.icon : "bell",
        title: director.linkTitle || i18n("notifications.desktop_toast.title"),
        message:
          sender && topic
            ? i18n("notifications.desktop_toast.sender_and_topic", {
                sender,
                topic,
              })
            : sender || topic,
        actions: href
          ? [
              {
                label: i18n("notifications.desktop_toast.open"),
                action: ({ close }) => {
                  close();
                  DiscourseURL.routeTo(href);
                },
              },
            ]
          : [],
      },
    });
  }
}

export default {
  after: "message-bus",
  initialize(owner) {
    this.instance = new SubscribeUserNotificationsInit(owner);
  },
  teardown() {
    this.instance.teardown();
    this.instance = null;
  },
};
