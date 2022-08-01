import UserMenuNotificationsList from "discourse/components/user-menu/notifications-list";

export default class UserMenuMentionsNotificationsList extends UserMenuNotificationsList {
  get filterByTypes() {
    return ["mentioned"];
  }
}
