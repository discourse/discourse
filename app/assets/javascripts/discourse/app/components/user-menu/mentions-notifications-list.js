import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";

export default class UserMenuMentionsNotificationsList extends UserMenuNotificationsList {
  get dismissTypes() {
    return this.filterByTypes;
  }

  dismissWarningModal() {
    return null;
  }
}
