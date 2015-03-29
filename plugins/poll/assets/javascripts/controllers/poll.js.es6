import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend({
  poll: null,
  showResults: Em.computed.oneWay('poll.closed'),
  disableRadio: Em.computed.any('poll.closed', 'loading'),
  showToggleClosePoll: Em.computed.alias('poll.post.topic.details.can_edit'),

  actions: {
    selectOption(option) {
      if (this.get('disableRadio')) {
        return;
      }

      if (!this.get('postController.currentUser.id')) {
        this.get('postController').send('showLogin');
        return;
      }

      this.set('loading', true);

      const self = this;
      this.get('poll').saveVote(option).then(function() {
        self.setProperties({ loading: false, showResults: true});
      });
    },

    toggleShowResults() {
      this.toggleProperty('showResults');
    },

    toggleClosePoll() {
      const self = this;

      this.set('loading', true);

      return Discourse.ajax('/poll/toggle_close', {
        type: 'PUT',
        data: { post_id: this.get('poll.post.id') }
      }).then(function(result) {
        self.set('poll.post.topic.title', result.basic_topic.title);
        self.set('poll.post.topic.fancy_title', result.basic_topic.title);
        self.set('loading', false);
      });
    }
  }
});

