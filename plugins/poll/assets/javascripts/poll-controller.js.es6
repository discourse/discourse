export default Discourse.Controller.extend({
  poll: null,
  showResults: Em.computed.oneWay('poll.closed'),
  disableRadio: Em.computed.any('poll.closed', 'loading'),
  showToggleClosePoll: function() {
    return this.get('poll.post.topic.details.can_edit') && !Discourse.SiteSettings.allow_user_locale;
  }.property('poll.post.topic.details.can_edit'),

  actions: {
    selectOption: function(option) {
      if (this.get('disableRadio')) {
        return;
      }

      if (!this.get('currentUser.id')) {
        this.get('postController').send('showLogin');
        return;
      }

      this.set('loading', true);
      this.get('poll').saveVote(option).then(function() {
        this.set('loading', false);
        this.set('showResults', true);
      }.bind(this));
    },

    toggleShowResults: function() {
      this.set('showResults', !this.get('showResults'));
    },

    toggleClosePoll: function() {
      this.set('loading', true);
      return Discourse.ajax("/poll/toggle_close", {
        type: "PUT",
        data: {post_id: this.get('poll.post.id')}
      }).then(function(topicJson) {
        this.set('poll.post.topic.title', topicJson.basic_topic.title);
        this.set('poll.post.topic.fancy_title', topicJson.basic_topic.title);
        this.set('loading', false);
      }.bind(this));
    }
  }
});

