export default Ember.Component.extend({

  postStream: Em.computed.alias('participant.topic.postStream'),
  showPostCount: Em.computed.gte('participant.post_count', 2),

  toggled: function() {
    return this.get('postStream.userFilters').contains(this.get('participant.username'));
  }.property('postStream.userFilters.[]'),

  actions: {
    toggle() {
      const postStream = this.get('postStream');
      if (postStream) {
        postStream.toggleParticipant(this.get('participant.username'));
      }
    }
  }
});
