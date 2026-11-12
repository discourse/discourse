import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";
import UserMenuOtherNotificationsListEmptyState from "discourse/components/user-menu/other-notifications-list-empty-state";

export default class UserMenuOtherNotificationsList extends UserMenuNotificationsList {
  get dismissTypes() {
    return this.filterByTypes;
  }

  get emptyStateComponent() {
    return UserMenuOtherNotificationsListEmptyState;
  }

  get renderDismissConfirmation() {
    return false;
  }
}
