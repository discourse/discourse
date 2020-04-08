import NotificationsButtonComponent from "select-kit/components/notifications-button";

export default NotificationsButtonComponent.extend({
  pluginApiIdentifiers: ["tag-notifications-button"],
  classNames: ["tag-notifications-button"],

  selectKitOptions: {
    showFullTitle: false,
    i18nPrefix: "i18nPrefix"
  },

  i18nPrefix: "tagging.notifications"
});
