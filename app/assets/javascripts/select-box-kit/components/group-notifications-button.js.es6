import NotificationOptionsComponent from "select-box-kit/components/notifications-button";

export default NotificationOptionsComponent.extend({
  classNames: ["group-notifications-button"],
  i18nPrefix: "groups.notifications",

  loadValueFunction() {
    return this.get("group.group_user.notification_level");
  },

  selectValueFunction(value) {
    this.get("group").setNotification(value, this.get("user.id"));
  }
});
