import Component from "@glimmer/component";
import { action } from "@ember/object";
import { empty } from "@ember/object/computed";
import { topicLevels } from "discourse/lib/notification-levels";
import { i18n } from "discourse-i18n";

// Support for changing the notification level of various topics
export default class NotificationLevel extends Component {
  notificationLevelId = null;

  @empty("notificationLevelId") disabled;

  get notificationLevels() {
    return topicLevels.map((level) => ({
      id: level.id.toString(),
      name: i18n(`topic.notifications.${level.key}.title`),
      description: i18n(`topic.notifications.${level.key}.description`),
    }));
  }

  @action
  changeNotificationLevel() {
    this.args.performAndRefresh({
      type: "change_notification_level",
      notification_level_id: this.notificationLevelId,
    });
  }
}
