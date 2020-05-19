import Component from "@ember/component";
import { action, computed } from "@ember/object";

export default Component.extend({
  layoutName: "select-kit/templates/components/topic-notifications-button",
  classNames: ["topic-notifications-button"],
  classNameBindings: ["isLoading"],
  appendReason: true,
  showFullTitle: true,
  placement: "bottom-start",
  notificationLevel: null,
  topic: null,
  showCaret: true,
  isLoading: false,
  icon: computed("isLoading", function() {
    return this.isLoading ? "spinner" : null;
  }),

  @action
  changeTopicNotificationLevel(levelId) {
    if (levelId !== this.notificationLevel) {
      this.set("isLoading", true);
      this.topic.details
        .updateNotifications(levelId)
        .finally(() => this.set("isLoading", false));
    }
  }
});
