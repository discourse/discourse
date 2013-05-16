/**
  This mixin allows a modal to list a selected posts count nicely.

  @class Discourse.SelectedPostsCount
  @extends Ember.Mixin
  @namespace Discourse
  @module Discourse
**/
Discourse.SelectedPostsCount = Em.Mixin.create({

  selectedPostsCount: function() {
    if (!this.get('selectedPosts')) return 0;

    if (this.get('allPostsSelected')) return this.get('posts_count') || this.get('topic.posts_count');

    return this.get('selectedPosts.length');
  }.property('selectedPosts.length', 'allPostsSelected')

});


