export default Discourse.GroupedView.extend({
  templateName: 'embedded-post',
  classNames: ['reply'],

  _startTracking: function() {
    const post = this.get('content');
    Discourse.ScreenTrack.current().track(this.get('elementId'), post.get('post_number'));
  }.on('didInsertElement'),

  _stopTracking: function() {
    Discourse.ScreenTrack.current().stopTracking(this.get('elementId'));
  }.on('willDestroyElement')
});
