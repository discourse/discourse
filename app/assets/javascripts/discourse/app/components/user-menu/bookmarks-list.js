import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";
import { ajax } from "discourse/lib/ajax";
import Notification from "discourse/models/notification";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";

export default class UserMenuBookmarksList extends UserMenuNotificationsList {
  get dismissTypes() {
    return ["bookmark_reminder"];
  }

  get showAllHref() {
    return `${this.currentUser.path}/activity/bookmarks`;
  }

  get showAllTitle() {
    return I18n.t("user_menu.view_all_bookmarks");
  }

  get showDismiss() {
    return this.#unreadBookmarkRemindersCount > 0;
  }

  get dismissTitle() {
    return I18n.t("user.dismiss_bookmarks_tooltip");
  }

  get itemsCacheKey() {
    return "user-menu-bookmarks-tab";
  }

  get itemComponent() {
    return "user-menu/bookmark-notification-item";
  }

  get emptyStateComponent() {
    return "user-menu/bookmarks-list-empty-state";
  }

  get #unreadBookmarkRemindersCount() {
    const key = `grouped_unread_high_priority_notifications.${this.site.notification_types.bookmark_reminder}`;
    // we're retrieving the value with get() so that Ember tracks the property
    // and re-renders the UI when it changes.
    // we can stop using `get()` when the User model is refactored into native
    // class with @tracked properties.
    return this.currentUser.get(key) || 0;
  }

  fetchItems() {
    return ajax(`/u/${this.currentUser.username}/user-menu-bookmarks`).then(
      (data) => {
        const content = [];
        data.notifications.forEach((notification) => {
          content.push(Notification.create(notification));
        });
        content.push(...data.bookmarks);
        return content;
      }
    );
  }

  dismissWarningModal() {
    const modalController = showModal("dismiss-notification-confirmation");
    modalController.set(
      "confirmationMessage",
      I18n.t("notifications.dismiss_confirmation.body.bookmarks", {
        count: this.#unreadBookmarkRemindersCount,
      })
    );
    return modalController;
  }
}
