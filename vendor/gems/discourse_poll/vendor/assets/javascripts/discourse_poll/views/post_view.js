(function() {
  window.Discourse.PostView.reopen({
    
    extraClass: function() {
      if (this.get('showVotes')) return 'votes';
      return null;
    }.property('showVotes'),

    showVotes: function() {
      var post = this.get('post');  
      if (post.get('post_number') === 1) return;
      if (post.get('post_type') !== Discourse.Post.REGULAR_TYPE) return;
      if (post.get('reply_to_post_number')) return;
      return (post.get('topic.archetype') === 'poll');
    }.property('post.post_number', 'post.post_type', 'post.reply_to_post_number')

  })
}).call(this); 