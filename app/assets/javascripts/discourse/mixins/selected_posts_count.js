/**
  This mixin allows a modal to list a selected posts count nicely.

  @class Discourse.SelectedPostsCount
  @extends Ember.Mixin
  @namespace Discourse
  @module Discourse
**/
Discourse.SelectedPostsCount = Em.Mixin.create({

  selectedPostsCount: function() {
    if (this.get('allPostsSelected')) return this.get('posts_count') || this.get('topic.posts_count');

    var sum = this.get('selectedPosts.length') || 0;
    if (this.get('selectedReplies')) {
      this.get('selectedReplies').forEach(function (p) {
        sum += p.get('reply_count') || 0;
      });
    }

    return sum;
  }.property('selectedPosts.length', 'allPostsSelected', 'selectedReplies.length'),

  /**
    The username that owns every selected post, or undefined if no selection or if
    ownership is mixed.

    @returns {String|undefined} username that owns all selected posts
  **/
  selectedPostsUsername: function() {
    // Don't proceed if replies are selected or usernames are mixed
    // Changing ownership in those cases normally doesn't make sense
    if (this.get('selectedReplies') && this.get('selectedReplies').length > 0) return;
    if (this.get('selectedPosts').length <= 0) return;

    var selectedPosts = this.get('selectedPosts'),
        username = selectedPosts[0].username;

    if (selectedPosts.every(function(post) { return post.username === username; })) {
      return username;
    }
  }.property('selectedPosts.length', 'selectedReplies.length')
});


