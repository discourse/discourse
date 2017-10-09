import NotificationOptionsComponent from "discourse/components/notifications-button";
import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import { topicLevels, buttonDetails } from "discourse/lib/notification-levels";

export default NotificationOptionsComponent.extend({
  classNames: "topic-notifications-options",
  content: topicLevels,
  i18nPrefix: "topic.notifications",
  value: Ember.computed.alias("topic.details.notification_level"),

  @on("didInsertElement")
  _bindGlobalLevelChanged() {
    this.appEvents.on("topic-notifications-button:changed", (msg) => {
      if (msg.type === "notification") {
        if (this.get("computedValue") !== msg.id) {
          this.get("topic.details").updateNotifications(msg.id);
        }
      }
    });
  },

  @on("willDestroyElement")
  _unbindGlobalLevelChanged() {
    this.appEvents.off("topic-notifications-button:changed");
  },

  @computed("computedValue", "showFullTitle")
  headerText(computedValue, showFullTitle) {
    if (showFullTitle) {
      const details = buttonDetails(computedValue);
      return I18n.t(`topic.notifications.${details.key}.title`);
    } else {
      return null;
    }
  },

  actions: {
    onSelect(value) {
      if (value !== this.get("computedValue")) {
        this.get("topic.details").updateNotifications(value);
      }

      this._super(value);
    }
  }
});
