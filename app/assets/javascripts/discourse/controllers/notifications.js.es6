import { url } from 'discourse/lib/computed';

export default Ember.ArrayController.extend({
  needs: ['header'],
  loadingNotifications: Em.computed.alias('controllers.header.loadingNotifications'),
  myNotificationsUrl: url('/my/notifications')
});
