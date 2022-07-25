import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";

export default class UserMenuRepliesNotificationsList extends UserMenuNotificationsList {
  get filterByTypes() {
    return ["replied"];
  }
}
