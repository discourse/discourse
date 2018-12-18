import NotificationOptionsComponent from "select-kit/components/notifications-button";
import computed from "ember-addons/ember-computed-decorators";

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
    return this.get("notificationLevel");
  },

  @computed("iconForSelectedDetails")
  headerIcon(iconForSelectedDetails) {
    return iconForSelectedDetails;
  }
});
