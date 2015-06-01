import LoadMore from "discourse/mixins/load-more";

export default Ember.View.extend(LoadMore, {
  eyelineSelector: '.user-stream .notification',
  classNames: ['user-stream', 'notification-history']
});
