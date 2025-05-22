import { service } from "@ember/service";
import NotificationTypeBase from "discourse/lib/notification-types/base";

export default class extends NotificationTypeBase {
  @service siteSettings;

  get label() {
    let name;

    if (!this.siteSettings.prioritize_username_in_ux) {
      name = this.notification.data.original_name || this.username;
    } else {
      name = this.username;
    }

    return `${name} @${this.notification.data.group_name}`;
  }

  get labelClasses() {
    return ["mention-group", "notify"];
  }
}
