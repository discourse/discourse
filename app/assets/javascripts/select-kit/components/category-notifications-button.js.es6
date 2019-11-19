import { or, alias } from "@ember/object/computed";
import NotificationOptionsComponent from "select-kit/components/notifications-button";

export default NotificationOptionsComponent.extend({
  pluginApiIdentifiers: ["category-notifications-button"],
  classNames: "category-notifications-button",
  isHidden: or("category.deleted"),
  headerIcon: alias("iconForSelectedDetails"),
  i18nPrefix: "category.notifications",
  showFullTitle: false,
  allowInitialValueMutation: false,

  mutateValue(value) {
    this.category.setNotification(value);
  },

  deselect() {}
});
