import UserMenuNotificationItem from "discourse/components/user-menu/notification-item";

export default class UserMenuGroupMentionedNotificationItem extends UserMenuNotificationItem {
  get label() {
    return `${this.username} @${this.notification.data.group_name}`;
  }

  get labelWrapperClasses() {
    return "mention-group notify";
  }
}
