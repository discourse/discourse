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
  }.property('selectedPosts.length', 'allPostsSelected', 'selectedReplies.length')

});


