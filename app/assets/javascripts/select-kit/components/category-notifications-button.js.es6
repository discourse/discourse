import NotificationOptionsComponent from "select-kit/components/notifications-button";

export default NotificationOptionsComponent.extend({
  pluginApiIdentifiers: ["category-notifications-button"],
  classNames: "category-notifications-button",
  isHidden: Ember.computed.or("category.deleted"),
  headerIcon: Ember.computed.alias("iconForSelectedDetails"),
  i18nPrefix: "category.notifications",
  showFullTitle: false,
  allowInitialValueMutation: false,

  mutateValue(value) {
    this.get("category").setNotification(value);
  }
});
