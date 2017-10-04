import NotificationOptionsComponent from "discourse/components/notifications-button";

export default NotificationOptionsComponent.extend({
  classNames: ["group-notifications-button"],

  value: Em.computed.alias("group.group_user.notification_level"),

  i18nPrefix: "groups.notifications",

  actions: {
    onSelect(content) {
      this._super(content);

      this.get("group").setNotification(this.get("value"), this.get("user.id"));
    }
  }
});
