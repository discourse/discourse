(function() {
  window.Discourse.Post.reopen({

    voteAction: function () {
      return this.get('actionByName.vote');
    }.property('actionByName.vote'),

    // We never show "replies below" for polls.
    replyBelowUrl: function() {
      if (this.get('topic.archetype') === 'poll') return null;
      return this.get('replyBelowUrlComputed');
    }.property('replyBelowUrlComputed', 'topic.archetype'),

    // Vote for this post
    vote: function() {
      voteType = Discourse.get('site.post_action_types').findProperty('name_key', 'vote');
      this.get('voteAction').act();
      Em.run.next(function () {
        this.set('topic.voted_in_topic', true);
      }.bind(this));
      return false;
    },

    cantVote: function() {

      if (!Discourse.get('currentUser')) {
        bootbox.alert(I18n.t('vote.not_logged_in'));
        return false;
      }

      bootbox.alert(I18n.t('vote.cant'));
      return false;
    },

    undoVote: function() {
      voteType = Discourse.get('site.post_action_types').findProperty('name_key', 'vote');
      this.get('voteAction').undo();
      Em.run.next(function () {
        this.set('topic.voted_in_topic', false);
      }.bind(this));
      return false;
    }

  });
}).call(this);
