import discourseComputed from "discourse-common/utils/decorators";
import { empty } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import { topicLevels } from "discourse/lib/notification-levels";

// Support for changing the notification level of various topics
export default Controller.extend({
  topicBulkActions: inject(),
  notificationLevelId: null,

  @discourseComputed
  notificationLevels() {
    return topicLevels.map(level => {
      return {
        id: level.id.toString(),
        name: I18n.t(`topic.notifications.${level.key}.title`),
        description: I18n.t(`topic.notifications.${level.key}.description`)
      };
    });
  },

  disabled: empty("notificationLevelId"),

  actions: {
    changeNotificationLevel() {
      this.topicBulkActions.performAndRefresh({
        type: "change_notification_level",
        notification_level_id: this.notificationLevelId
      });
    }
  }
});
