import NotificationOptionsComponent from "discourse/components/notifications-button";
import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import { topicLevels, buttonDetails } from "discourse/lib/notification-levels";

export default NotificationOptionsComponent.extend({
  classNames: ["topic-notifications-options"],

  content: topicLevels,

  i18nPrefix: "topic.notifications",

  value: Ember.computed.alias("topic.details.notification_level"),

  @on("didInsertElement")
  _bindGlobalLevelChanged() {
    this.appEvents.on("topic-notifications-button:changed", (msg) => {
      if (msg.type === "notification") {
        if (this.get("value") !== msg.id) {
          this.get("topic.details").updateNotifications(msg.id);
        }
      }
    });
  },

  @on("willDestroyElement")
  _unbindGlobalLevelChanged() {
    this.appEvents.off("topic-notifications-button:changed");
  },

  @computed("value", "showFullTitle")
  generatedHeadertext(value, showFullTitle) {
    if (showFullTitle) {
      const details = buttonDetails(value);
      return I18n.t(`topic.notifications.${details.key}.title`);
    } else {
      return null;
    }
  },

  actions: {
    onSelectRow(content) {
      const notificationLevelId = Ember.get(content, this.get("idKey"));

      if (notificationLevelId !== this.get("value")) {
        this.get("topic.details").updateNotifications(notificationLevelId);
      }

      this._super(content);
    }
  }
});
