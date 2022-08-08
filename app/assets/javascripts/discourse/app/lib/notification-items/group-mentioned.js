import NotificationItemBase from "discourse/lib/notification-items/base";

export default class extends NotificationItemBase {
  get label() {
    return `${this.username} @${this.notification.data.group_name}`;
  }

  get labelWrapperClasses() {
    return ["mention-group", "notify"];
  }
}
