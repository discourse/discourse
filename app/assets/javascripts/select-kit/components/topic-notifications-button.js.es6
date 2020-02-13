import Component from "@ember/component";

export default Component.extend({
  layoutName: "select-kit/templates/components/topic-notifications-button",
  classNames: ["topic-notifications-button"],
  appendReason: true,
  showFullTitle: true,

  didInsertElement() {
    this._super(...arguments);

    this.appEvents.on(
      "topic-notifications-button:changed",
      this,
      "_changeTopicNotificationLevel"
    );
  },

  willDestroyElement() {
    this._super(...arguments);

    this.appEvents.off(
      "topic-notifications-button:changed",
      this,
      "_changeTopicNotificationLevel"
    );
  },

  _changeTopicNotificationLevel(level) {
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
