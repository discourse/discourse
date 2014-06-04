/**
  A button to display notification options for categories.

  @class NotificationsButton
  @extends Discourse.DropdownButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.CategoryNotificationsButton = Discourse.NotificationsButton.extend({
  classNames: ['notification-options', 'category-notification-menu'],
  buttonIncludesText: false,
  longDescriptionBinding: null,
  hidden: Em.computed.alias('category.deleted'),
  notificationLevels: Discourse.Category.NotificationLevel,
  notificationLevel: Em.computed.alias('category.notification_level'),
  i18nPrefix: 'category.notifications',
  i18nPostfix: '',

  clicked: function(id) {
    this.get('category').setNotification(id);
  }
});
