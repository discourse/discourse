import NotificationItemBase from "discourse/lib/notification-items/base";

export default class extends NotificationItemBase {
  get label() {
    return `${this.username} @${this.notification.data.group_name}`;
  }

  get labelClasses() {
    return ["mention-group", "notify"];
  }
}
