const PageTracker = Ember.Object.extend(Ember.Evented);
let _pageTracker = PageTracker.create();

let _started = false;
export function startPageTracking(router) {
  if (_started) { return; }

  router.on('didTransition', function() {
    this.send('refreshTitle');
    const url = Discourse.getURL(this.get('url'));

    // Refreshing the title is debounced, so we need to trigger this in the
    // next runloop to have the correct title.
    Em.run.next(() => {
      _pageTracker.trigger('change', url, Discourse.get('_docTitle'));
    });
  });
  _started = true;
}

export function onPageChange(fn) {
  _pageTracker.on('change', fn);
}

// backwards compatibility
const BackwardsCompat = {
  current() {
    console.warn(`Using PageTracker.current() is deprecated. Your plugin should use the PluginAPI`);
    return _pageTracker;
  }
};

Discourse.PageTracker = BackwardsCompat;
export default BackwardsCompat;
