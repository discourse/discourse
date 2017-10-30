import NotificationOptionsComponent from "select-box-kit/components/notifications-button";

export default NotificationOptionsComponent.extend({
  classNames: ["group-notifications-button"],
  value: Ember.computed.alias("group.group_user.notification_level"),
  i18nPrefix: "groups.notifications",

  actions: {
    onSelect(value) {
      value = this.defaultOnSelect(value);
      this.get("group").setNotification(value, this.get("user.id"));
    }
  }
});
