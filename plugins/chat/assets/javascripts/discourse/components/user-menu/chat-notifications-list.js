import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";
import UserMenuChatNotificationsListEmptyState from "discourse/plugins/chat/discourse/components/user-menu/chat-notifications-list-empty-state";

export default class UserMenuChatNotificationsList extends UserMenuNotificationsList {
  get dismissTypes() {
    return this.filterByTypes;
  }

  get emptyStateComponent() {
    return UserMenuChatNotificationsListEmptyState;
  }
}
