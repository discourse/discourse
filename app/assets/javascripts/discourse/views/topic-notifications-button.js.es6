import NotificationsButton from 'discourse/views/notifications-button';

export default NotificationsButton.extend({
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
