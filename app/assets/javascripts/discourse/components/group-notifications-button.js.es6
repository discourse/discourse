import NotificationOptionsComponent from "discourse/components/notifications-button";
import { observes } from "ember-addons/ember-computed-decorators";

export default NotificationOptionsComponent.extend({
  classNames: ["group-notifications-button"],

  value: Em.computed.alias("group.group_user.notification_level"),

  i18nPrefix: "groups.notifications",

  @observes("value")
  _notificationLevelChanged() {
    this.get("group").setNotification(this.get("value"), this.get("user.id"));
  }
});
