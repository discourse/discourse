export default Ember.View.extend(Discourse.LoadMore, {
  eyelineSelector: '.user-stream .notification',
  classNames: ['user-stream', 'notification-history'],
  templateName: 'user/notifications'
});
