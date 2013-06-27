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
    Discourse.ScreenTrack.instance().track(this.get('elementId'), this.get('post.post_number'));
  },

  willDestroyElement: function() {
    Discourse.ScreenTrack.instance().stopTracking(this.get('elementId'));
  }

});


