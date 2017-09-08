import NotificationOptionsComponent from "discourse/components/notification-options";
import { observes } from "ember-addons/ember-computed-decorators";

export default NotificationOptionsComponent.extend({
  classNames: ["group-notification-options"],

  value: Em.computed.alias("group.group_user.notification_level"),

  i18nPrefix: "groups.notifications",

  @observes("value")
  _notificationLevelChanged() {
    this.get("group").setNotification(this.get("value"), this.get("user.id"));
  }
});
