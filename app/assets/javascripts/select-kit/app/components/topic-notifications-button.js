import Component from "@ember/component";
import { action } from "@ember/object";

export default Component.extend({
  layoutName: "select-kit/templates/components/topic-notifications-button",
  classNames: ["topic-notifications-button"],
  appendReason: true,
  showFullTitle: true,
  placement: "bottom-start",
  notificationLevel: null,
  topic: null,

  @action
  changeTopicNotificationLevel(levelId) {
    if (levelId !== this.notificationLevel) {
      this.topic.details.updateNotifications(levelId);
    }
  }
});
