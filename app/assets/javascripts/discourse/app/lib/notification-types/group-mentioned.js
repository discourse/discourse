import NotificationTypeBase from "discourse/lib/notification-types/base";

export default class extends NotificationTypeBase {
  get label() {
    return `${this.username} @${this.notification.data.group_name}`;
  }

  get labelClasses() {
    return ["mention-group", "notify"];
  }
}
