export default Em.Mixin.create({

  selectedPostsCount: function() {
    if (this.get('allPostsSelected')) {
      return this.get('model.posts_count') || this.get('topic.posts_count') || this.get('posts_count');
    }

    var sum = this.get('selectedPosts.length') || 0;
    if (this.get('selectedReplies')) {
      this.get('selectedReplies').forEach(function (p) {
        sum += p.get('reply_count') || 0;
      });
    }

    return sum;
  }.property('selectedPosts.length', 'allPostsSelected', 'selectedReplies.length'),

  // The username that owns every selected post, or undefined if no selection or if ownership is mixed.
  selectedPostsUsername: function() {
    // Don't proceed if replies are selected or usernames are mixed
    // Changing ownership in those cases normally doesn't make sense
    if (this.get('selectedReplies') && this.get('selectedReplies').length > 0) { return undefined; }
    if (this.get('selectedPosts').length <= 0) { return undefined; }

    const selectedPosts = this.get('selectedPosts'),
          username = selectedPosts[0].username;

    if (selectedPosts.every(function(post) { return post.username === username; })) {
      return username;
    } else {
      return undefined;
    }
  }.property('selectedPosts.length', 'selectedReplies.length')
});
