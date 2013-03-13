(function() {
  Discourse.PostActionType.reopen({

    isVote: function() {
      return (this.get('name_key') === 'vote');
    }.property('name_key')

  });
}).call(this);
