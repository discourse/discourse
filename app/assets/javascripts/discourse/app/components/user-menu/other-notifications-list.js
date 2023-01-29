import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";

export default class UserMenuOtherNotificationsList extends UserMenuNotificationsList {
  get dismissTypes() {
    return this.filterByTypes;
  }

  get emptyStateComponent() {
    return "user-menu/other-notifications-list-empty-state";
  }

  dismissWarningModal() {
    return null;
  }
}
