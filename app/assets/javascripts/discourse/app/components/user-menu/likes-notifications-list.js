import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";

export default class UserMenuLikesNotificationsList extends UserMenuNotificationsList {
  get filterByTypes() {
    return ["liked", "liked_consolidated"];
  }
}
