import { ajax } from "discourse/lib/ajax";
import { createWidgetFrom } from "discourse/widgets/widget";
import QuickAccessPanel from "discourse/widgets/quick-access-panel";

createWidgetFrom(QuickAccessPanel, "quick-access-notifications", {
  buildKey: () => "quick-access-notifications",
  emptyStatePlaceholderItemKey: "notifications.empty",

  markReadRequest() {
    return ajax("/notifications/mark-read", { method: "PUT" });
  },

  newItemsLoaded() {
    if (!this.currentUser.enforcedSecondFactor) {
      this.currentUser.set("unread_notifications", 0);
    }
  },

  itemHtml(notification) {
    const notificationName = this.site.notificationLookup[
      notification.notification_type
    ];

    return this.attach(
      `${notificationName.dasherize()}-notification-item`,
      notification,
      {},
      { fallbackWidgetName: "default-notification-item" }
    );
  },

  findNewItems() {
    return this._findStaleItemsInStore().refresh();
  },

  showAllHref() {
    return `${this.attrs.path}/notifications`;
  },

  hasUnread() {
    return this.getItems().filterBy("read", false).length > 0;
  },

  _findStaleItemsInStore() {
    return this.store.findStale(
      "notification",
      {
        recent: true,
        silent: this.currentUser.enforcedSecondFactor,
        limit: this.estimateItemLimit()
      },
      { cacheKey: "recent-notifications" }
    );
  }
});
