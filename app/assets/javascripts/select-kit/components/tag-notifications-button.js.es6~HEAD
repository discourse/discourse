import NotificationOptionsComponent from "select-kit/components/notifications-button";
import computed from "ember-addons/ember-computed-decorators";

export default NotificationOptionsComponent.extend({
  classNames: "tag-notifications-button",
  i18nPrefix: "tagging.notifications",
  showFullTitle: false,
  allowInitialValueMutation: false,

  mutateValue(value) {
    this.sendAction("action", value);
  },

  @computed("iconForSelectedDetails")
  headerIcon(iconForSelectedDetails) {
    return [iconForSelectedDetails, "caret-down"];
  }
});
