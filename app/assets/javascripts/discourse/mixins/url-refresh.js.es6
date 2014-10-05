// A Mixin that a view can use to listen for 'url:refresh' when
// it is on screen, and will send an action to the controller to
// refresh its data.
//
// This is useful if you want to get around Ember's default
// behavior of not refreshing when navigating to the same place.
export default Em.Mixin.create({
  _initURLRefresh: function() {
    this.appEvents.on('url:refresh', this, '_urlRefresh');
  }.on('didInsertElement'),

  _tearDownURLRefresh: function() {
    this.appEvents.off('url:refresh', this, '_urlRefresh');
  }.on('willDestroyElement'),

  _urlRefresh: function() {
    this.get('controller').send('refresh');
  }
});
