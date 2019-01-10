import computed from "ember-addons/ember-computed-decorators";
import { topicLevels } from "discourse/lib/notification-levels";

// Support for changing the notification level of various topics
export default Ember.Controller.extend({
  topicBulkActions: Ember.inject.controller(),
  notificationLevelId: null,

  @computed
  notificationLevels() {
    return topicLevels.map(level => {
      return {
        id: level.id.toString(),
        name: I18n.t(`topic.notifications.${level.key}.title`),
        description: I18n.t(`topic.notifications.${level.key}.description`)
      };
    });
  },

  disabled: Ember.computed.empty("notificationLevelId"),

  actions: {
    changeNotificationLevel() {
      this.get("topicBulkActions").performAndRefresh({
        type: "change_notification_level",
        notification_level_id: this.get("notificationLevelId")
      });
    }
  }
});
