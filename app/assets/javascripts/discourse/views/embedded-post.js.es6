/**
  This view handles rendering of post within another (such as a collapsed reply)

  @class EmbeddedPostView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
export default Discourse.GroupedView.extend({
  templateName: 'embedded_post',
  classNames: ['reply'],

  _startTracking: function() {
    var post = this.get('content');
    Discourse.ScreenTrack.current().track(this.get('elementId'), post.get('post_number'));
  }.on('didInsertElement'),

  _stopTracking: function() {
    Discourse.ScreenTrack.current().stopTracking(this.get('elementId'));
  }.on('willDestroyElement')

});
