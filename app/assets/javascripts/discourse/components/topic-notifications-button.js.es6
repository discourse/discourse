import NotificationsButton from 'discourse/components/notifications-button';

export default NotificationsButton.extend({
  longDescription: Em.computed.alias('topic.details.notificationReasonText'),
  hidden: Em.computed.alias('topic.deleted'),
  notificationLevel: Em.computed.alias('topic.details.notification_level'),
  i18nPrefix: 'topic.notifications',

  i18nPostfix: function() {
    return this.get('topic.isPrivateMessage') ? '_pm' : '';
  }.property('topic.isPrivateMessage'),

  clicked(id) {
    this.get('topic.details').updateNotifications(id);
  }
});
