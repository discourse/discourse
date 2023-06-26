import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";

export default class UserMenuLikesNotificationsList extends UserMenuNotificationsList {
  get dismissTypes() {
    return this.filterByTypes;
  }

  displayDismissWarning() {
    return false;
  }

  get emptyStateComponent() {
    return "user-menu/likes-list-empty-state";
  }
}
