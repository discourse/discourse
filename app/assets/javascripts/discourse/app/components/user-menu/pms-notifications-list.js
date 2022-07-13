import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";
import showModal from "discourse/lib/show-modal";
import I18n from "I18n";

export default class UserMenuPmsNotificationsList extends UserMenuNotificationsList {
  get filterByTypes() {
    return ["private_message"];
  }

  dismissWarningModal() {
    const unreadCount =
      this.currentUser.grouped_unread_high_priority_notifications[
        this.site.notification_types.private_message
      ];
    if (unreadCount && unreadCount > 0) {
      const modalController = showModal("dismiss-notification-confirmation");
      modalController.set(
        "confirmationMessage",
        I18n.t("notifications.dismiss_confirmation.body.pms", {
          count: unreadCount,
        })
      );
      return modalController;
    }
  }
}
