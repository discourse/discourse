/**
  This view is used for rendering a list of replies below a post

  @class RepliesView
  @extends Ember.CollectionView
  @namespace Discourse
  @module Discourse
**/
export default Ember.CollectionView.extend({
  tagName: 'section',
  classNameBindings: [':embedded-posts', ':bottom', 'hidden'],
  itemViewClass: 'embedded-post',
  hidden: Em.computed.equal('content.length', 0)
});
