import Component from "@ember/component";

export default Component.extend({
  layoutName: "select-kit/templates/components/topic-notifications-button",
  classNames: ["topic-notifications-button"],
  appendReason: true,
  showFullTitle: true,
  placement: "bottom-start",

  didInsertElement() {
    this._super(...arguments);

    if (!this.mountedAsWidget) {
      this.appEvents.on(
        "topic-notifications-button:changed",
        this,
        "_changeTopicNotificationLevel"
      );
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    if (!this.mountedAsWidget) {
      this.appEvents.off(
        "topic-notifications-button:changed",
        this,
        "_changeTopicNotificationLevel"
      );
    }
  },

  _changeTopicNotificationLevel(level) {
    // this change is coming from a keyboard event
    if (level.event) {
      const topicSectionNode = level.event.target.querySelector("#topic");
      if (topicSectionNode && topicSectionNode.dataset.topicId) {
        const topicId = parseInt(topicSectionNode.dataset.topicId, 10);
        if (topicId && topicId !== this.topic.id) {
          return;
        }
      }
    }

    if (level.id !== this.notificationLevel) {
      this.topic.details.updateNotifications(level.id);
    }
  },

  actions: {
    changeTopicNotificationLevel(level, notification) {
      this._changeTopicNotificationLevel(notification);
    }
  }
});
