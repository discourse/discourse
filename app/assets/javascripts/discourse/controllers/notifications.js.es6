export default Ember.ArrayController.extend(Discourse.HasCurrentUser, {
  needs: ['header'],
  loadingNotifications: Em.computed.alias('controllers.header.loadingNotifications')
});
