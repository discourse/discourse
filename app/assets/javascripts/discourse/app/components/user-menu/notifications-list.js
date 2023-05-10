import UserMenuItemsList from "discourse/components/user-menu/items-list";
import I18n from "I18n";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import {
  mergeSortedLists,
  postRNWebviewMessage,
} from "discourse/lib/utilities";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import Notification from "discourse/models/notification";
import UserMenuReviewable from "discourse/models/user-menu-reviewable";
import UserMenuReviewableItem from "discourse/lib/user-menu/reviewable-item";

export default class UserMenuNotificationsList extends UserMenuItemsList {
  @service appEvents;
  @service currentUser;
  @service siteSettings;
  @service site;
  @service store;

  get filterByTypes() {
    return this.args.filterByTypes;
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
    return Object.keys(
      this.currentUser.get("grouped_unread_notifications") || {}
    ).any((key) => {
      return this.currentUser.get(`grouped_unread_notifications.${key}`) > 0;
    });
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
    };

    if (this.currentUser.enforcedSecondFactor) {
      params.silent = true;
    }

    const types = this.filterByTypes;
    if (types?.length > 0) {
      params.filter_by_types = types.join(",");
      params.silent = true;
    }

    const content = [];
    const data = await ajax("/notifications", { data: params });

    const notifications = await Notification.initializeNotifications(
      data.notifications
    );

    const reviewables = data.pending_reviewables?.map((r) =>
      UserMenuReviewable.create(r)
    );

    if (reviewables?.length) {
      const firstReadNotificationIndex = notifications.findIndex((n) => n.read);
      const unreadNotifications = notifications.splice(
        0,
        firstReadNotificationIndex
      );
      mergeSortedLists(
        unreadNotifications,
        reviewables,
        (notification, reviewable) => {
          const notificationCreatedAt = new Date(notification.created_at);
          const reviewableCreatedAt = new Date(reviewable.created_at);
          return reviewableCreatedAt > notificationCreatedAt;
        }
      ).forEach((item) => {
        const props = {
          appEvents: this.appEvents,
          currentUser: this.currentUser,
          siteSettings: this.siteSettings,
          site: this.site,
        };
        if (item instanceof Notification) {
          props.notification = item;
          content.push(new UserMenuNotificationItem(props));
        } else {
          props.reviewable = item;
          content.push(new UserMenuReviewableItem(props));
        }
      });
    }

    notifications.forEach((notification) => {
      content.push(
        new UserMenuNotificationItem({
          notification,
          appEvents: this.appEvents,
          currentUser: this.currentUser,
          siteSettings: this.siteSettings,
          site: this.site,
        })
      );
    });
    return content;
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
