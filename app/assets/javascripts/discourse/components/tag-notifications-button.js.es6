import NotificationsButton from 'discourse/components/notifications-button';

export default NotificationsButton.extend({
  classNames: ['notification-options', 'tag-notification-menu'],
  buttonIncludesText: false,
  i18nPrefix: 'tagging.notifications',

  clicked(id) {
    this.sendAction('action', id);
  }
});
