/**
  This view is used for rendering a list of replies below a post

  @class RepliesView
  @extends Ember.CollectionView
  @namespace Discourse
  @module Discourse
**/
Discourse.RepliesView = Ember.CollectionView.extend({
  tagName: 'section',
  classNameBindings: [':embedded-posts', ':bottom', 'hidden'],
  itemViewClass: Discourse.EmbeddedPostView,
  hidden: Em.computed.equal('content.length', 0)
});


