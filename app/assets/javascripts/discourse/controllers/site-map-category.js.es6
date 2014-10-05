export default Ember.ObjectController.extend(Discourse.HasCurrentUser, {
  needs: ['site-map'],

  unreadTotal: function() {
    return parseInt(this.get('unreadTopics'), 10) +
           parseInt(this.get('newTopics'), 10);
  }.property('unreadTopics', 'newTopics'),

  showTopicCount: Em.computed.not('currentUser')
});
