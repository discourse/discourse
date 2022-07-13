import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";

export default class UserMenuBadgesNotificationsList extends UserMenuNotificationsList {
  get filterByTypes() {
    return ["granted_badge"];
  }

  dismissWarningModal() {
    return null;
  }
}
