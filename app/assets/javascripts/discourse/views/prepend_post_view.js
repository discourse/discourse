/**
  This view allows us to prepend content to a post (for use in plugins)

  @class PrependPostView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.PrependPostView = Em.ContainerView.extend({
  init: function() {
    this._super();
    return this.trigger('prependPostContent');
  }
});


