/**
  A button to display topic notification options.

  @class TopicNotificationsButton
  @extends Discourse.NotificationsButton
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicNotificationsButton = Discourse.NotificationsButton.extend({
  longDescriptionBinding: 'topic.details.notificationReasonText',
  topic: Em.computed.alias('controller.model'),
  target: Em.computed.alias('topic'),
  hidden: Em.computed.alias('topic.deleted'),
  notificationLevels: Discourse.Topic.NotificationLevel,
  notificationLevel: Em.computed.alias('topic.details.notification_level'),
  isPrivateMessage: Em.computed.alias('topic.isPrivateMessage'),
  i18nPrefix: 'topic.notifications',

  i18nPostfix: function() {
    return this.get('isPrivateMessage') ? '_pm' : '';
  }.property('isPrivateMessage'),

  clicked: function(id) {
    this.get('topic.details').updateNotifications(id);
  }
});

