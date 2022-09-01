import UserMenuItemsList from "discourse/components/user-menu/items-list";
import I18n from "I18n";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { postRNWebviewMessage } from "discourse/lib/utilities";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import Notification from "discourse/models/notification";

export default class UserMenuNotificationsList extends UserMenuItemsList {
  @service currentUser;
  @service siteSettings;
  @service site;
  @service store;

  get filterByTypes() {
    return null;
  }

  get dismissTypes() {
    return null;
  }

  get showAllHref() {
    return `${this.currentUser.path}/notifications`;
  }

  get showAllTitle() {
    return I18n.t("user_menu.view_all_notifications");
  }

  get showDismiss() {
    return this.items.some((item) => !item.notification.read);
  }

  get dismissTitle() {
    return I18n.t("user.dismiss_notifications_tooltip");
  }

  get itemsCacheKey() {
    let key = "recent-notifications";
    const types = this.filterByTypes;
    if (types?.length > 0) {
      key += `-type-${types.join(",")}`;
    }
    return key;
  }

  get emptyStateComponent() {
    if (this.constructor === UserMenuNotificationsList) {
      return "user-menu/notifications-list-empty-state";
    } else {
      return super.emptyStateComponent;
    }
  }

  async fetchItems() {
    const params = {
      limit: 30,
      recent: true,
      bump_last_seen_reviewable: true,
      silent: this.currentUser.enforcedSecondFactor,
    };

    const types = this.filterByTypes;
    if (types?.length > 0) {
      params.filter_by_types = types.join(",");
      params.silent = true;
    }
    const collection = await this.store
      .findStale("notification", params)
      .refresh();
    const notifications = collection.content;
    await Notification.applyTransformations(notifications);
    return notifications.map((notification) => {
      return new UserMenuNotificationItem({
        notification,
        currentUser: this.currentUser,
        siteSettings: this.siteSettings,
        site: this.site,
      });
    });
  }

  dismissWarningModal() {
    if (this.currentUser.unread_high_priority_notifications > 0) {
      const modalController = showModal("dismiss-notification-confirmation");
      modalController.set(
        "confirmationMessage",
        I18n.t("notifications.dismiss_confirmation.body.default", {
          count: this.currentUser.unread_high_priority_notifications,
        })
      );
      return modalController;
    }
  }

  @action
  dismissButtonClick() {
    const opts = { type: "PUT" };
    const dismissTypes = this.dismissTypes;
    if (dismissTypes?.length > 0) {
      opts.data = { dismiss_types: dismissTypes.join(",") };
    }
    const modalController = this.dismissWarningModal();
    const modalCallback = () => {
      ajax("/notifications/mark-read", opts).then(() => {
        if (dismissTypes) {
          const unreadNotificationCountsHash = {
            ...this.currentUser.grouped_unread_notifications,
          };
          dismissTypes.forEach((type) => {
            const typeId = this.site.notification_types[type];
            if (typeId) {
              delete unreadNotificationCountsHash[typeId];
            }
          });
          this.currentUser.set(
            "grouped_unread_notifications",
            unreadNotificationCountsHash
          );
        } else {
          this.currentUser.set("all_unread_notifications_count", 0);
          this.currentUser.set("unread_high_priority_notifications", 0);
          this.currentUser.set("grouped_unread_notifications", {});
        }
        this.refreshList();
        postRNWebviewMessage("markRead", "1");
      });
    };
    if (modalController) {
      modalController.set("dismissNotifications", modalCallback);
    } else {
      modalCallback();
    }
  }
}
