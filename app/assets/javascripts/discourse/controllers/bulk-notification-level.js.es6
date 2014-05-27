/**
  Support for changing the notification level of various topics

  @class BulkNotificationLevelControler
  @extends Ember.Controller
  @namespace Discourse
  @module Discourse
**/
export default Em.Controller.extend({
  needs: ['topic-bulk-actions'],

  notificationLevelId: null,

  notificationLevels: function() {
    var result = [];
    Object.keys(Discourse.Topic.NotificationLevel).forEach(function(k) {
      result.push({
        id: Discourse.Topic.NotificationLevel[k].toString(),
        name: I18n.t('topic.notifications.' + k.toLowerCase() + ".title"),
        description: I18n.t('topic.notifications.' + k.toLowerCase() + ".description")
      });
    });
    return result;
  }.property(),

  disabled: Em.computed.empty("notificationLevelId"),

  actions: {
    changeNotificationLevel: function() {
      this.get('controllers.topic-bulk-actions').performAndRefresh({
        type: 'change_notification_level',
        notification_level_id: this.get('notificationLevelId')
      });
    }
  }
});
