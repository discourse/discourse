/**
  This view is used to handle the interface for multi selecting of posts.

  @class SelectedPostsView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.SelectedPostsView = Discourse.View.extend({
  elementId: 'selected-posts',
  templateName: 'selected_posts',
  topicBinding: 'controller.content',
  classNameBindings: ['customVisibility'],

  customVisibility: (function() {
    if (!this.get('controller.multiSelect')) return 'hidden';
  }).property('controller.multiSelect')

});


