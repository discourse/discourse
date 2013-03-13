/**
  This view handles rendering of post within another (such as a collapsed reply)

  @class EmbeddedPostView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.EmbeddedPostView = Discourse.View.extend({
  templateName: 'embedded_post',
  classNames: ['reply'],

  didInsertElement: function() {
    var postView = this.get('postView') || this.get('parentView.postView');
    return postView.get('screenTrack').track(this.get('elementId'), this.get('post.post_number'));
  }

});


