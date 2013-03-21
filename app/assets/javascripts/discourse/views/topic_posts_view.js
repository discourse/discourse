/**
  This view is for rendering the posts in a topic

  @class TopicPostsView
  @extends Ember.CollectionView
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicPostsView = Em.CollectionView.extend({
  itemViewClass: Discourse.PostView
});


