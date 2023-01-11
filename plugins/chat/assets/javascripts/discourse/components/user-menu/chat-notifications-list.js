import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";

export default class UserMenuChatNotificationsList extends UserMenuNotificationsList {
  get dismissTypes() {
    return this.filterByTypes;
  }

  get emptyStateComponent() {
    return "user-menu/chat-notifications-list-empty-state";
  }
}
