import Component from "@glimmer/component";
import I18n from "I18n";
import { empty } from "@ember/object/computed";
import { topicLevels } from "discourse/lib/notification-levels";
import { action } from "@ember/object";

// Support for changing the notification level of various topics
export default class NotificationLevel extends Component {
  notificationLevelId = null;

  @empty("notificationLevelId") disabled;

  get notificationLevels() {
    return topicLevels.map((level) => ({
      id: level.id.toString(),
      name: I18n.t(`topic.notifications.${level.key}.title`),
      description: I18n.t(`topic.notifications.${level.key}.description`),
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
