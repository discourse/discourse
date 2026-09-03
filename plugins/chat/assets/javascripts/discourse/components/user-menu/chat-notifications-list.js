import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";
import ChatNotificationsListEmptyState from "./chat-notifications-list-empty-state";

export default class UserMenuChatNotificationsList extends UserMenuNotificationsList {
  get dismissTypes() {
    return this.filterByTypes;
  }

  get emptyStateComponent() {
    return ChatNotificationsListEmptyState;
  }
}
