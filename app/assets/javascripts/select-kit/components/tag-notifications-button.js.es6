import NotificationOptionsComponent from "select-kit/components/notifications-button";
import discourseComputed from "discourse-common/utils/decorators";

export default NotificationOptionsComponent.extend({
  pluginApiIdentifiers: ["tag-notifications-button"],
  classNames: "tag-notifications-button",
  i18nPrefix: "tagging.notifications",
  showFullTitle: false,
  allowInitialValueMutation: false,

  mutateValue(value) {
    this.action(value);
  },

  computeValue() {
    return this.notificationLevel;
  },

  @discourseComputed("iconForSelectedDetails")
  headerIcon(iconForSelectedDetails) {
    return iconForSelectedDetails;
  }
});
