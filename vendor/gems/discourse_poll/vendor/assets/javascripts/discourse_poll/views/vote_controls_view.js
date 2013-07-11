(function() {
  window.Discourse.VoteControlsView = Em.View.extend({
    templateName: 'discourse_poll/templates/poll_controls',
    classNameBindings: ['pollControlsClass'],
    postBinding: 'parentView.post',
    showVotesBinding: 'parentView.parentView.showVotes',

    canSeeWhoVoted: function() {
      if (this.get('post.voteAction.count') === 0) return false;
      return !this.get('controller.content.private_poll');
    }.property('post.voteAction.count'),

    showVoteControls: function() {
      if (!Discourse.get('currentUser')) return false;
      if (this.get('post.post_number') === 1) return;
      if (this.get('post.topic.single_vote') && this.get('post.topic.voted_in_topic')) return false;
      if (this.get('post.topic.archived')) return false;
      return true;
    }.property('post.post_number', 'post.topic.archived', 'post.topic.single_vote', 'post.topic.voted_in_topic'),

    pollControlsClass: function() {
      if (this.get('post.post_number') === 1) return;
      if (this.get('post.reply_to_post_number')) return;
      return 'poll-controls';
    }.property('showVoteControls'),

    canUndo: function() {
      return true;
    }.property(),

    voteDisabled: function() {
      return !this.get('post.voteAction.can_act');
    }.property('post.voteAction.can_act'),

    voteButtonText: function() {
      if (!this.get('post.voteAction.can_act')) return I18n.t("vote.voted");
      return I18n.t("vote.title");
    }.property('post.voteAction.can_act')

  })
}).call(this);
