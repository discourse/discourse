import NotificationOptionsComponent from "select-box-kit/components/notifications-button";
import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default NotificationOptionsComponent.extend({
  classNames: "category-notifications-button",

  isHidden: Ember.computed.or("category.deleted", "site.isMobileDevice"),

  i18nPrefix: "category.notifications",

  value: Ember.computed.alias("category.notification_level"),

  @computed("computedValue")
  headerIcon(computedValue) {
    return `${this._super(computedValue)}${iconHTML("caret-down")}`.htmlSafe();
  },

  headerText: null,

  actions: {
    onSelect(value) {
      this.defaultOnSelect();

      this.get("category").setNotification(value);
    }
  }
});
