import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";
import { ajax } from "discourse/lib/ajax";
import Notification from "discourse/models/notification";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import UserMenuMessageItem from "discourse/lib/user-menu/message-item";
import Topic from "discourse/models/topic";
import { mergeSortedLists } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";

export default class UserMenuMessagesList extends UserMenuNotificationsList {
  @service store;

  get dismissTypes() {
    return this.filterByTypes;
  }

  get showAllHref() {
    return `${this.currentUser.path}/messages`;
  }

  get showAllTitle() {
    return I18n.t("user_menu.view_all_messages");
  }

  get showDismiss() {
    return this.#unreadMessagesNotifications > 0;
  }

  get dismissTitle() {
    return I18n.t("user.dismiss_messages_tooltip");
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
        content.push(new UserMenuMessageItem({ message: item }));
      }
    });

    return content;
  }

  dismissWarningModal() {
    const modalController = showModal("dismiss-notification-confirmation");
    modalController.set(
      "confirmationMessage",
      I18n.t("notifications.dismiss_confirmation.body.messages", {
        count: this.#unreadMessagesNotifications,
      })
    );
    return modalController;
  }
}
