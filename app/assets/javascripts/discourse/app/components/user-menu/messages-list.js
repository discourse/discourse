import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";
import { ajax } from "discourse/lib/ajax";
import Notification from "discourse/models/notification";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";
import { all } from "rsvp";

export default class UserMenuMessagesList extends UserMenuNotificationsList {
  get dismissTypes() {
    return ["private_message"];
  }

  get showAllHref() {
    return `${this.currentUser.path}/messages`;
  }

  get showAllTitle() {
    return I18n.t("user_menu.view_all_messages");
  }

  get showDismiss() {
    return this.#unreadMessaagesNotifications > 0;
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

  get #unreadMessaagesNotifications() {
    const key = `grouped_unread_high_priority_notifications.${this.site.notification_types.private_message}`;
    // we're retrieving the value with get() so that Ember tracks the property
    // and re-renders the UI when it changes.
    // we can stop using `get()` when the User model is refactored into native
    // class with @tracked properties.
    return this.currentUser.get(key) || 0;
  }

  fetchItems() {
    return ajax(
      `/u/${this.currentUser.username}/user-menu-private-messages`
    ).then((data) => {
      const notifications = data.notifications.map((notification) =>
        Notification.create(notification)
      );
      const messages = data.topics;
      return all([
        this.applyListProcessorsFromPlugins("notifications", notifications),
        this.applyListProcessorsFromPlugins("messages", messages),
      ]).then(() => {
        const notificationClass = this.findItemRendererClass("notification");
        const messageClass = this.findItemRendererClass("message");
        return [
          ...notifications.map((notification) => {
            return new notificationClass({
              notification,
              currentUser: this.currentUser,
              siteSettings: this.siteSettings,
              site: this.site,
            });
          }),
          ...messages.map((message) => {
            return new messageClass({ message });
          }),
        ];
      });
    });
  }

  dismissWarningModal() {
    const modalController = showModal("dismiss-notification-confirmation");
    modalController.set(
      "confirmationMessage",
      I18n.t("notifications.dismiss_confirmation.body.messages", {
        count: this.#unreadMessaagesNotifications,
      })
    );
    return modalController;
  }
}
