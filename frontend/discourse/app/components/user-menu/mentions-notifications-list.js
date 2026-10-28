import UserMenuMentionsListEmptyState from "discourse/components/user-menu/mentions-list-empty-state";
import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";

export default class UserMenuMentionsNotificationsList extends UserMenuNotificationsList {
  get dismissTypes() {
    return this.filterByTypes;
  }

  get emptyStateComponent() {
    return UserMenuMentionsListEmptyState;
  }

  get renderDismissConfirmation() {
    return false;
  }

  get showAllHref() {
    return `${this.currentUser.path}/notifications/mentions`;
  }
}
