import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";

export default class UserMenuLikesNotificationsList extends UserMenuNotificationsList {
  get dismissTypes() {
    return this.filterByTypes;
  }

  get renderDismissConfirmation() {
    return false;
  }

  get emptyStateComponent() {
    return "user-menu/likes-list-empty-state";
  }
}
