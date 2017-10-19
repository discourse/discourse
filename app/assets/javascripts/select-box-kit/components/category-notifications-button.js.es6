import NotificationOptionsComponent from "select-box-kit/components/notifications-button";

export default NotificationOptionsComponent.extend({
  classNames: "category-notifications-button",
  isHidden: Ember.computed.or("category.deleted", "site.isMobileDevice"),
  i18nPrefix: "category.notifications",
  value: Ember.computed.alias("category.notification_level"),
  headerComponent: "category-notifications-button/category-notifications-button-header",

  actions: {
    onSelect(value) {
      value = this.defaultOnSelect(value);
      this.get("category").setNotification(value);
      this.blur();
    }
  }
});
