import NotificationOptionsComponent from "select-kit/components/notifications-button";
import computed from "ember-addons/ember-computed-decorators";

export default NotificationOptionsComponent.extend({
  pluginApiIdentifiers: ["category-notifications-button"],
  classNames: "category-notifications-button",
  isHidden: Ember.computed.or("category.deleted", "site.isMobileDevice"),
  i18nPrefix: "category.notifications",
  showFullTitle: false,
  allowInitialValueMutation: false,

  mutateValue(value) {
    this.get("category").setNotification(value);
  },

  @computed("iconForSelectedDetails")
  headerIcon(iconForSelectedDetails) {
    return [iconForSelectedDetails];
  }
});
