import NotificationOptionsComponent from "select-kit/components/notifications-button";

export default NotificationOptionsComponent.extend({
  pluginApiIdentifiers: ["group-notifications-button"],
  classNames: ["group-notifications-button"],

  selectKitOptions: {
    i18nPrefix: "i18nPrefix"
  },

  i18nPrefix: "groups.notifications"
});
