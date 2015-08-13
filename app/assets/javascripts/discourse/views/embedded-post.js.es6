import ScreenTrack from 'discourse/lib/screen-track';

export default Discourse.GroupedView.extend({
  templateName: 'embedded-post',
  classNames: ['reply'],

  _startTracking: function() {
    const post = this.get('content');
    ScreenTrack.current().track(this.get('elementId'), post.get('post_number'));
  }.on('didInsertElement'),

  _stopTracking: function() {
    ScreenTrack.current().stopTracking(this.get('elementId'));
  }.on('willDestroyElement')
});
