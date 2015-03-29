export default Ember.ArrayController.extend({
  needs: ['header'],
  loadingNotifications: Em.computed.alias('controllers.header.loadingNotifications')
});
