import Component from "@ember/component";

export default Component.extend({
  layoutName: "select-kit/templates/components/topic-notifications-button",
  classNames: ["topic-notifications-button"],
  appendReason: true,
  showFullTitle: true,

  actions: {
    changeTopicNotificationLevel(newNotificationLevel) {
      if (newNotificationLevel !== this.notificationLevel) {
        this.topic.details.updateNotifications(newNotificationLevel);
      }
    }
  }
});
