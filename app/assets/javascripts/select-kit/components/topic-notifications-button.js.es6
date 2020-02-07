import Component from "@ember/component";
import { computed } from "@ember/object";
import { later } from "@ember/runloop";

export default Component.extend({
  layoutName: "select-kit/templates/components/topic-notifications-button",
  classNames: ["topic-notifications-button"],
  appendReason: true,
  showFullTitle: true,
  isLoading: false,
  icon: computed("isLoading", function() {
    return this.isLoading ? "spinner" : null;
  }),

  actions: {
    changeTopicNotificationLevel(newNotificationLevel) {
      if (newNotificationLevel !== this.notificationLevel) {
        this.set("isLoading", true);
        this.topic.details
          .updateNotifications(newNotificationLevel)
          .finally(() => later(() => this.set("isLoading", false), 250));
      }
    }
  }
});
