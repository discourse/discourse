import NotificationOptionsComponent from "discourse/components/notification-options";
import { observes } from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default NotificationOptionsComponent.extend({
  classNames: ["category-notification-options"],

  classNameBindings: ["hidden:is-hidden"],
  hidden: Ember.computed.or("category.deleted", "site.isMobileDevice"),

  i18nPrefix: "category.notifications",

  value: Em.computed.alias("category.notification_level"),

  generatedHeadertext: iconHTML("caret-down").htmlSafe(),

  @observes("value")
  _notificationLevelChanged() {
    this.get("category").setNotification(this.get("value"));
  },
});
