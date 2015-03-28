const NotificationsController = Ember.ArrayController.extend({
  needs: ['header'],
  loadingNotifications: Em.computed.alias('controllers.header.loadingNotifications'),
  myNotificationsUrl: Discourse.computed.url('/my/notifications')
});

export default NotificationsController;
