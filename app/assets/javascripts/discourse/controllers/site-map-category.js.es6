export default Ember.Controller.extend({
  needs: ['site-map'],

  unreadTotal: function() {
    return parseInt(this.get('model.unreadTopics'), 10) +
           parseInt(this.get('model.newTopics'), 10);
  }.property('model.unreadTopics', 'model.newTopics'),

  showTopicCount: Em.computed.not('currentUser')
});
