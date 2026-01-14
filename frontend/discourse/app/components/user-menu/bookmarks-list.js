import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";
import { ajax } from "discourse/lib/ajax";
import UserMenuBookmarkItem from "discourse/lib/user-menu/bookmark-item";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import Bookmark from "discourse/models/bookmark";
import Notification from "discourse/models/notification";
import { i18n } from "discourse-i18n";

export default class UserMenuBookmarksList extends UserMenuNotificationsList {
  get dismissTypes() {
    return ["bookmark_reminder"];
  }

  get showAllHref() {
    return `${this.currentUser.path}/activity/bookmarks`;
  }

  get showAllTitle() {
    return i18n("user_menu.view_all_bookmarks");
  }

  get showDismiss() {
    return this.#unreadBookmarkRemindersCount > 0;
  }

  get dismissTitle() {
    return i18n("user.dismiss_bookmarks_tooltip");
  }

  get itemsCacheKey() {
    return "user-menu-bookmarks-tab";
  }

  get emptyStateComponent() {
    return "user-menu/bookmarks-list-empty-state";
  }

  get #unreadBookmarkRemindersCount() {
    const key = `grouped_unread_notifications.${this.site.notification_types.bookmark_reminder}`;
    // we're retrieving the value with get() so that Ember tracks the property
    // and re-renders the UI when it changes.
    // we can stop using `get()` when the User model is refactored into native
    // class with @tracked properties.
    return this.currentUser.get(key) || 0;
  }

  get dismissConfirmationText() {
    return i18n("notifications.dismiss_confirmation.body.bookmarks", {
      count: this.#unreadBookmarkRemindersCount,
    });
  }

  async fetchItems() {
    const data = await ajax(
      `/u/${this.currentUser.username}/user-menu-bookmarks`
    );
    const content = [];

    const notifications = data.notifications.map((n) => Notification.create(n));
    await Notification.applyTransformations(notifications);
    notifications.forEach((notification) => {
      content.push(
        new UserMenuNotificationItem({
          notification,
          currentUser: this.currentUser,
          siteSettings: this.siteSettings,
          site: this.site,
        })
      );
    });

    const bookmarks = data.bookmarks.map((b) => Bookmark.create(b));
    await Bookmark.applyTransformations(bookmarks);
    content.push(
      ...bookmarks.map((bookmark) => {
        return new UserMenuBookmarkItem({
          bookmark,
          siteSettings: this.siteSettings,
          site: this.site,
        });
      })
    );

    return content;
  }
}
