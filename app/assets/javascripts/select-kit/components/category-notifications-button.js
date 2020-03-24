import { or } from "@ember/object/computed";
import NotificationOptionsComponent from "select-kit/components/notifications-button";

export default NotificationOptionsComponent.extend({
  pluginApiIdentifiers: ["category-notifications-button"],
  classNames: ["category-notifications-button"],
  isHidden: or("category.deleted"),

  selectKitOptions: {
    i18nPrefix: "i18nPrefix",
    showFullTitle: false
  },

  i18nPrefix: "category.notifications"
});
