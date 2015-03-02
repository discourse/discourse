import NotificationsButton from 'discourse/components/notifications-button';

export default NotificationsButton.extend({
  classNames: ['notification-options', 'category-notification-menu'],
  buttonIncludesText: false,
  hidden: Em.computed.alias('category.deleted'),
  notificationLevel: Em.computed.alias('category.notification_level'),
  i18nPrefix: 'category.notifications',

  clicked(id) {
    this.get('category').setNotification(id);
  }
});
