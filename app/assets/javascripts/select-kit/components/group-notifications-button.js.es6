import NotificationOptionsComponent from "select-kit/components/notifications-button";

export default NotificationOptionsComponent.extend({
  pluginApiIdentifiers: ["grouo-notifications-button"],
  classNames: ["group-notifications-button"],
  i18nPrefix: "groups.notifications",
  allowInitialValueMutation: false,

  mutateValue(value) {
    this.get("group").setNotification(value, this.get("user.id"));
  }
});
