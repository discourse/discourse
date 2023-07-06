import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";

export default class UserMenuRepliesNotificationsList extends UserMenuNotificationsList {
  get dismissTypes() {
    return this.filterByTypes;
  }

  get renderDismissConfirmation() {
    return false;
  }

  get emptyStateComponent() {
    return "user-menu/notifications-list-empty-state";
  }
}
