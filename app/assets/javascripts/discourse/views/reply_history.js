/**
  Lists previous posts in the history of a post.

  @class ReplyHistory
  @extends Discourse.EmbeddedPostView
  @namespace Discourse
  @module Discourse
**/
Discourse.ReplyHistory = Em.CollectionView.extend({
  tagName: 'section',
  classNameBindings: [':embedded-posts', ':top', ':span14', ':offset2', 'hidden'],
  itemViewClass: Discourse.EmbeddedPostView,
  hidden: Em.computed.equal('content.length', 0),
  previousPost: true
});


