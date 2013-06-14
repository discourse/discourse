/**
  This view allows us to prepend content to a post (for use in plugins)

  @class PrependPostView
  @extends Discourse.ContainerView
  @namespace Discourse
  @module Discourse
**/
Discourse.PrependPostView = Discourse.ContainerView.extend({
  init: function() {
    this._super();
    return this.trigger('prependPostContent');
  }
});


