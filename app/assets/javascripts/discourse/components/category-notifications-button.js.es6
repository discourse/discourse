import NotificationOptionsComponent from "discourse/components/notifications-button";
import { observes } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default NotificationOptionsComponent.extend({
  classNames: ["category-notifications-button"],

  classNameBindings: ["hidden:is-hidden"],
  hidden: Ember.computed.or("category.deleted", "site.isMobileDevice"),

  i18nPrefix: "category.notifications",

  value: Em.computed.alias("category.notification_level"),

  @computed("value")
  icon() {
    return `${this._super()}${iconHTML("caret-down")}`.htmlSafe();
  },

  generatedHeadertext: null,

  @observes("value")
  _notificationLevelChanged() {
    this.get("category").setNotification(this.get("value"));
  },
});
