import NotificationOptionsComponent from "discourse/components/notifications-button";
import { observes, on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import { topicLevels, buttonDetails } from "discourse/lib/notification-levels";

export default NotificationOptionsComponent.extend({
  classNames: ["topic-notifications-options"],

  content: topicLevels,
  i18nPrefix: "topic.notifications",

  @on("init")
  _setInitialNotificationLevel() {
    this.set("value", this.get("topic.details.notification_level"));
  },

  @on("didInsertElement")
  _bindGlobalLevelChanged() {
    this.appEvents.on("topic-notifications-button:changed", (msg) => {
      if (msg.type === "notification") {
        if (this.get("topic.details.notification_level") !== msg.id) {
          this.get("topic.details").updateNotifications(msg.id);
        }
      }
    });
  },

  @on("willDestroyElement")
  _unbindGlobalLevelChanged() {
    this.appEvents.off("topic-notifications-button:changed");
  },

  @observes("value")
  _notificationLevelChanged() {
    this.appEvents.trigger("topic-notifications-button:changed", {type: "notification", id: this.get("value")});
  },

  @observes("topic.details.notification_level")
  _content() {
    this.set("value", this.get("topic.details.notification_level"));
  },

  @computed("topic.details.notification_level", "showFullTitle")
  generatedHeadertext(notificationLevel, showFullTitle) {
    if (showFullTitle) {
      const details = buttonDetails(notificationLevel);
      return I18n.t(`topic.notifications.${details.key}.title`);
    } else {
      return null;
    }
  }
});
