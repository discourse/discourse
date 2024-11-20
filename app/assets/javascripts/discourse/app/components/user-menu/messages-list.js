import { service } from "@ember/service";
import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";
import { ajax } from "discourse/lib/ajax";
import UserMenuMessageItem from "discourse/lib/user-menu/message-item";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import { mergeSortedLists } from "discourse/lib/utilities";
import Notification from "discourse/models/notification";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";

export default class UserMenuMessagesList extends UserMenuNotificationsList {
  @service store;

  get dismissTypes() {
    return this.filterByTypes;
  }

  get showAllHref() {
    return `${this.currentUser.path}/messages`;
  }

  get showAllTitle() {
    return i18n("user_menu.view_all_messages");
  }

  get showDismiss() {
    return this.#unreadMessagesNotifications > 0;
  }

  get dismissTitle() {
    return i18n("user.dismiss_messages_tooltip");
  }

  get itemsCacheKey() {
    return "user-menu-messages-tab";
  }

  get emptyStateComponent() {
    return "user-menu/messages-list-empty-state";
  }

  get #unreadMessagesNotifications() {
    const key = `grouped_unread_notifications.${this.site.notification_types.private_message}`;
    // we're retrieving the value with get() so that Ember tracks the property
    // and re-renders the UI when it changes.
    // we can stop using `get()` when the User model is refactored into native
    // class with @tracked properties.
    return this.currentUser.get(key) || 0;
  }

  get dismissConfirmationText() {
    return i18n("notifications.dismiss_confirmation.body.messages", {
      count: this.#unreadMessagesNotifications,
    });
  }

  async fetchItems() {
    const data = await ajax(
      `/u/${this.currentUser.username}/user-menu-private-messages`
    );
    const content = [];

    const unreadNotifications = await Notification.initializeNotifications(
      data.unread_notifications
    );
    unreadNotifications.forEach((notification) => {
      content.push(
        new UserMenuNotificationItem({
          notification,
          currentUser: this.currentUser,
          siteSettings: this.siteSettings,
          site: this.site,
        })
      );
    });

    const topics = data.topics.map((t) => this.store.createRecord("topic", t));
    await Topic.applyTransformations(topics);

    if (this.siteSettings.show_user_menu_avatars) {
      // Populate avatar_template for lastPoster
      const usersById = new Map(data.users.map((u) => [u.id, u]));
      topics.forEach((t) => {
        t.last_poster_avatar_template = usersById.get(
          t.lastPoster.user_id
        )?.avatar_template;
      });
    }

    const readNotifications = await Notification.initializeNotifications(
      data.read_notifications
    );

    mergeSortedLists(readNotifications, topics, (notification, topic) => {
      const notificationCreatedAt = new Date(notification.created_at);
      const topicBumpedAt = new Date(topic.bumped_at);
      return topicBumpedAt > notificationCreatedAt;
    }).forEach((item) => {
      if (item instanceof Notification) {
        content.push(
          new UserMenuNotificationItem({
            notification: item,
            currentUser: this.currentUser,
            siteSettings: this.siteSettings,
            site: this.site,
          })
        );
      } else {
        content.push(
          new UserMenuMessageItem({
            message: item,
            siteSettings: this.siteSettings,
            site: this.site,
          })
        );
      }
    });

    return content;
  }
}
