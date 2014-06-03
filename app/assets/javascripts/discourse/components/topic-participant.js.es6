export default Ember.Component.extend({

  postStream: Em.computed.alias('participant.topic.postStream'),

  toggled: function() {
    return this.get('postStream.userFilters').contains(this.get('participant.username'));
  }.property('postStream.userFilters.[]'),

  actions: {
    toggle: function() {
      var postStream = this.get('postStream');
      if (postStream) {
        postStream.toggleParticipant(this.get('participant.username'));
      }
    }
  }
});
